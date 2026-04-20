UNAME_S := $(shell uname -s)

CMAKE_ARGS ?=

COLOR_CYAN := \033[36m
COLOR_RESET := \033[0m

GCOV_EXECUTABLE_Linux := gcov
GCOV_EXECUTABLE_Darwin := xcrun llvm-cov gcov

ifeq ($(UNAME_S),Darwin)
HOMEBREW_LLVM_PREFIX := $(shell brew --prefix llvm 2>/dev/null)
ifneq ($(HOMEBREW_LLVM_PREFIX),)
export PATH := $(HOMEBREW_LLVM_PREFIX)/bin:$(PATH)
endif
endif

GCOV_EXECUTABLE ?= $(GCOV_EXECUTABLE_$(UNAME_S))

ifeq ($(GCOV_EXECUTABLE),)
$(error unsupported host OS '$(UNAME_S)'; set GCOV_EXECUTABLE='<cmd>' to override)
endif

.DEFAULT_GOAL := help

ifneq ($(VERBOSE),1)
.SILENT:
endif

.SECONDEXPANSION:

# ---------------------------------------------------------------------------
# Conan configuration — release gets its own profile state, coverage reuses the
# debug toolchain, and sanitize uses a dedicated Conan profile so dependency
# binaries are rebuilt with matching instrumentation.
# ---------------------------------------------------------------------------
CONAN_PROFILE ?= profiles/default
CONAN_STAMP_debug := debug
CONAN_STAMP_release := release
CONAN_STAMP_sanitize := sanitize
CONAN_STAMP_coverage := debug

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
STAMP_DIR := build/.stamps
COVERAGE_DIR := build/coverage
FORMAT_SOURCES = $(shell find include src tests -type f \( -name '*.hpp' -o -name '*.cpp' \))
TIDY_SOURCES = $(shell find src tests -type f -name '*.cpp')

define require-tool
	command -v $(1) >/dev/null || { echo "$(1) not found"; exit 1; }
endef

# ---------------------------------------------------------------------------
# Conan lock file (lazy — regenerated when conanfile.py changes)
# ---------------------------------------------------------------------------
conan.lock: conanfile.py $(CONAN_PROFILE)
	echo "Regenerating conan.lock..."
	conan lock create . -s compiler.cppstd=23 -pr=$(CONAN_PROFILE) --lockfile-out=conan.lock

# ---------------------------------------------------------------------------
# Conan install
# ---------------------------------------------------------------------------
$(STAMP_DIR)/debug.stamp: BUILD_TYPE = Debug
$(STAMP_DIR)/release.stamp: BUILD_TYPE = Release
$(STAMP_DIR)/debug.stamp $(STAMP_DIR)/release.stamp: conan.lock
	echo "Installing Conan dependencies ($(BUILD_TYPE))..."
	mkdir -p $(STAMP_DIR)
	conan install . -pr=$(CONAN_PROFILE) -s compiler.cppstd=23 -s build_type=$(BUILD_TYPE) --build=missing --lockfile=conan.lock
	touch $@

$(STAMP_DIR)/sanitize.stamp: conan.lock
	echo "Installing Conan dependencies (sanitize)..."
	mkdir -p $(STAMP_DIR)
	conan install . -pr=profiles/sanitize -s compiler.cppstd=23 --build=missing --lockfile=conan.lock
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
bootstrap: $(STAMP_DIR)/debug.stamp $(STAMP_DIR)/release.stamp ## Install Conan dependencies for debug+release
.PHONY: bootstrap-sanitize
bootstrap-sanitize: $(STAMP_DIR)/sanitize.stamp ## Install sanitizer-instrumented Conan dependencies

# ---------------------------------------------------------------------------
# Build + test via workflow presets
# ---------------------------------------------------------------------------
.PHONY: debug
debug: ## Build and test via the debug workflow preset

.PHONY: release
release: ## Build and test via the release workflow preset

.PHONY: sanitize
sanitize: ## Build and test via the sanitize workflow preset

.PHONY: coverage
coverage: coverage-data-clean ## Build and test via the coverage workflow preset

debug release sanitize coverage: %: $(STAMP_DIR)/$$(CONAN_STAMP_%).stamp
	cmake --preset $@ $(CMAKE_ARGS)
	cmake --build --preset $@
	ctest --preset $@

# ---------------------------------------------------------------------------
# Coverage report generation
# ---------------------------------------------------------------------------
.PHONY: coverage-data-clean
coverage-data-clean:
	-find $(COVERAGE_DIR) -name '*.gcda' -delete

.PHONY: coverage-report
coverage-report: coverage ## Generate gcovr coverage report after running coverage
	$(call require-tool,python3)
	mkdir -p $(COVERAGE_DIR)/coverage-report
	python3 -m gcovr --root . \
		--gcov-executable "$(GCOV_EXECUTABLE)" \
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
lint: $(STAMP_DIR)/debug.stamp ## Run clang-tidy against the debug compilation database
	$(call require-tool,clang-tidy)
	cmake --preset debug $(CMAKE_ARGS)
	PATH="$(PATH)" clang-tidy -p build/debug $(TIDY_SOURCES)

.PHONY: format
format: ## Format C++ sources in place with clang-format
	echo "Formatting C++ sources..."
	$(call require-tool,clang-format)
	PATH="$(PATH)" clang-format -i $(FORMAT_SOURCES)

.PHONY: format-check
format-check: ## Fail if C++ sources are not clang-format clean
	echo "Checking C++ formatting..."
	$(call require-tool,clang-format)
	PATH="$(PATH)" clang-format --dry-run --Werror $(FORMAT_SOURCES)

# ---------------------------------------------------------------------------
# Lock and clean
# ---------------------------------------------------------------------------
.PHONY: lock
lock: conan.lock ## Ensure conan.lock is up to date

.PHONY: clean
clean: ## Remove generated build artifacts and Conan preset files
	echo "Removing generated artifacts..."
	rm -rf build/ compile_commands.json CMakeUserPresets.json ConanPresets.json
