LLVM_PREFIX ?= $(shell brew --prefix llvm 2>/dev/null || true)
LLVM_BIN := $(if $(wildcard $(LLVM_PREFIX)/bin/clang-format),$(LLVM_PREFIX)/bin,)
UNAME_S := $(shell uname -s)

CONAN ?= conan
CMAKE ?= cmake
GCOVR ?= gcovr

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
# Conan configuration — only two build types. Sanitizers and coverage are just
# CMake cache variables layered on top of the debug toolchain.
# ---------------------------------------------------------------------------
CONAN_STD := -s compiler.cppstd=23
CONAN_PROFILE_Linux := profiles/linux
CONAN_PROFILE_Darwin := profiles/macos
CONAN_PROFILE ?= $(CONAN_PROFILE_$(UNAME_S))

ifeq ($(CONAN_PROFILE),)
$(error unsupported host OS '$(UNAME_S)'; set CONAN_PROFILE=profiles/<name> to override)
endif

CONAN_INSTALL_ARGS := $(CONAN_STD) --build=missing --lockfile=conan.lock -pr=$(CONAN_PROFILE)

CONAN_BUILD_TYPE_debug   := Debug
CONAN_BUILD_TYPE_release := Release

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
	$(CONAN) lock create . $(CONAN_STD) -pr=$(CONAN_PROFILE) --lockfile-out=conan.lock

# ---------------------------------------------------------------------------
# Conan install (single generic pattern rule)
# ---------------------------------------------------------------------------
$(STAMP_DIR)/%.stamp: conan.lock
	echo "Installing Conan dependencies ($*)..."
	mkdir -p $(STAMP_DIR)
	$(CONAN) install . -s build_type=$(CONAN_BUILD_TYPE_$*) $(CONAN_INSTALL_ARGS)
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
bootstrap: $(STAMP_DIR)/debug.stamp $(STAMP_DIR)/release.stamp ## Install Conan dependencies for all presets

# ---------------------------------------------------------------------------
# Build + test via workflow presets
# ---------------------------------------------------------------------------
.PHONY: debug release sanitize coverage
debug:    ## Build via the debug workflow preset
release:  ## Build and test via the release workflow preset
sanitize: ## Build and test via the sanitize workflow preset
coverage: ## Build, test, and generate gcovr coverage report

debug release sanitize:
	$(call bootstrap-check)
	$(CMAKE) --workflow --preset $@

# ---------------------------------------------------------------------------
# Coverage report generation (appended after the workflow runs tests)
# ---------------------------------------------------------------------------
coverage:
	$(call bootstrap-check)
	-find $(COVERAGE_DIR) -name '*.gcda' -delete
	$(CMAKE) --workflow --preset coverage
	$(call require-tool,$(GCOVR))
	mkdir -p $(COVERAGE_DIR)/coverage-report
	$(GCOVR) --root . \
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
	$(CMAKE) --preset debug
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
