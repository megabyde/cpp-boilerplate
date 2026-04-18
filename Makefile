LLVM_PREFIX ?= $(shell brew --prefix llvm 2>/dev/null || true)
LLVM_BIN := $(if $(wildcard $(LLVM_PREFIX)/bin/clang-format),$(LLVM_PREFIX)/bin,)
UNAME_S := $(shell uname -s)

CMAKE_ARGS ?=

COLOR_CYAN := \033[36m
COLOR_RESET := \033[0m
CONAN_PRESETS := ConanPresets.json

CLANG_FORMAT ?= $(if $(LLVM_BIN),$(LLVM_BIN)/clang-format,clang-format)
CLANG_TIDY ?= $(if $(LLVM_BIN),$(LLVM_BIN)/clang-tidy,clang-tidy)

.DEFAULT_GOAL := help

ifneq ($(VERBOSE),1)
.SILENT:
endif

.SECONDEXPANSION:

define bootstrap-check
@if [ ! -f $(CONAN_PRESETS) ]; then \
	echo "error: $(CONAN_PRESETS) missing. Run 'make bootstrap' first." >&2; \
	exit 1; \
fi
endef

# ---------------------------------------------------------------------------
# Conan configuration — release gets its own profile state, coverage reuses the
# debug toolchain, and sanitize uses a dedicated Conan profile so dependency
# binaries are rebuilt with matching instrumentation.
# ---------------------------------------------------------------------------
CONAN_STD := -s compiler.cppstd=23
CONAN_PROFILE ?= profiles/default
CONAN_INSTALL_ARGS := $(CONAN_STD) --build=missing --lockfile=conan.lock

CONAN_BUILD_TYPE_debug   := Debug
CONAN_BUILD_TYPE_release := Release
CONAN_STAMP_debug := debug
CONAN_STAMP_release := release
CONAN_STAMP_sanitize := sanitize
CONAN_STAMP_coverage := debug

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
STAMP_DIR := build/.stamps
COVERAGE_DIR := build/coverage
FORMAT_FILES = $(shell find include src tests -type f \( -name '*.hpp' -o -name '*.cpp' \))
TIDY_SOURCES := $(shell find src tests -type f -name '*.cpp')

define require-tool
	command -v $(1) >/dev/null || { echo "$(1) not found"; exit 1; }
endef

# ---------------------------------------------------------------------------
# Conan lock file (lazy — regenerated when conanfile.py changes)
# ---------------------------------------------------------------------------
conan.lock: conanfile.py $(CONAN_PROFILE)
	echo "Regenerating conan.lock..."
	conan lock create . $(CONAN_STD) -pr=$(CONAN_PROFILE) --lockfile-out=conan.lock

# ---------------------------------------------------------------------------
# Conan install
# ---------------------------------------------------------------------------
$(STAMP_DIR)/%.stamp: conan.lock
	echo "Installing Conan dependencies ($*)..."
	mkdir -p $(STAMP_DIR)
	conan install . -pr=$(CONAN_PROFILE) -s build_type=$(CONAN_BUILD_TYPE_$*) $(CONAN_INSTALL_ARGS)
	touch $@

$(STAMP_DIR)/sanitize.stamp: conan.lock
	echo "Installing Conan dependencies (sanitize)..."
	mkdir -p $(STAMP_DIR)
	conan install . -pr=profiles/sanitize $(CONAN_INSTALL_ARGS)
	touch $@

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------
.PHONY: help
help: ## Show this help message
	@awk 'BEGIN {FS = ":.*##"; printf "Usage: make [options] $(COLOR_CYAN)[target] ...$(COLOR_RESET)\n\n"} \
	/^[a-zA-Z_-]+:.*##/ {printf "  $(COLOR_CYAN)%-16s$(COLOR_RESET) %s\n", $$1, $$2}' \
	$(MAKEFILE_LIST)

.PHONY: bootstrap
bootstrap: $(STAMP_DIR)/debug.stamp $(STAMP_DIR)/release.stamp $(STAMP_DIR)/sanitize.stamp ## Install Conan dependencies for all presets

# ---------------------------------------------------------------------------
# Build + test via workflow presets
# ---------------------------------------------------------------------------
.PHONY: debug release sanitize coverage
debug:    ## Build via the debug workflow preset
release:  ## Build and test via the release workflow preset
sanitize: ## Build and test via the sanitize workflow preset
coverage: ## Build, test, and generate gcovr coverage report

debug: $(STAMP_DIR)/debug.stamp
	$(call bootstrap-check)
	cmake --preset debug $(CMAKE_ARGS)
	cmake --build --preset debug

release sanitize: %: $(STAMP_DIR)/$$(CONAN_STAMP_%).stamp
	$(call bootstrap-check)
	cmake --preset $@ $(CMAKE_ARGS)
	cmake --build --preset $@
	ctest --preset $@

# ---------------------------------------------------------------------------
# Coverage report generation (appended after the workflow runs tests)
# ---------------------------------------------------------------------------
coverage: $(STAMP_DIR)/$$(CONAN_STAMP_coverage).stamp
	$(call bootstrap-check)
	rm -rf $(COVERAGE_DIR)
	mkdir -p $(COVERAGE_DIR)
	cmake --preset coverage $(CMAKE_ARGS)
	cmake --build --preset coverage
	ctest --preset coverage
	$(call require-tool,python3)
	mkdir -p $(COVERAGE_DIR)/coverage-report
	python3 -m gcovr --root . \
		--filter 'include/' --filter 'src/' \
		--exclude 'tests/' \
		--html-details $(COVERAGE_DIR)/coverage-report/index.html \
		--cobertura $(COVERAGE_DIR)/coverage.xml \
		--txt-summary \
		$(COVERAGE_DIR)

# ---------------------------------------------------------------------------
# Lint and format
# ---------------------------------------------------------------------------
.PHONY: lint
lint: ## Run clang-tidy against the debug compilation database
	$(call bootstrap-check)
	$(call require-tool,$(CLANG_TIDY))
	cmake --preset debug $(CMAKE_ARGS)
	$(CLANG_TIDY) -p build/debug $(TIDY_SOURCES)

.PHONY: format
format: ## Format C++ sources in place with clang-format
	echo "Formatting C++ sources..."
	$(call require-tool,$(CLANG_FORMAT))
	$(CLANG_FORMAT) -i $(FORMAT_FILES)

.PHONY: format-check
format-check: ## Fail if C++ sources are not clang-format clean
	$(call bootstrap-check)
	echo "Checking C++ formatting..."
	$(call require-tool,$(CLANG_FORMAT))
	$(CLANG_FORMAT) --dry-run --Werror $(FORMAT_FILES)

# ---------------------------------------------------------------------------
# Lock and clean
# ---------------------------------------------------------------------------
.PHONY: lock
lock: conan.lock ## Ensure conan.lock is up to date

.PHONY: clean
clean: ## Remove generated build artifacts and Conan preset files
	echo "Removing generated artifacts..."
	rm -rf build/ ConanPresets.json compile_commands.json CMakeUserPresets.json
