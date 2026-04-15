LLVM_PREFIX ?= $(shell brew --prefix llvm 2>/dev/null || true)
LLVM_BIN := $(if $(wildcard $(LLVM_PREFIX)/bin/clang-format),$(LLVM_PREFIX)/bin,)
UNAME_S := $(shell uname -s)

CONAN ?= conan
CMAKE ?= cmake
LCOV ?= lcov
GENHTML ?= genhtml

COLOR_CYAN := \033[36m
COLOR_RESET := \033[0m

CLANG_FORMAT ?= $(if $(LLVM_BIN),$(LLVM_BIN)/clang-format,clang-format)
CLANG_TIDY ?= $(if $(LLVM_BIN),$(LLVM_BIN)/clang-tidy,clang-tidy)

.DEFAULT_GOAL := help

ifneq ($(VERBOSE),1)
.SILENT:
endif

.SECONDEXPANSION:

# ---------------------------------------------------------------------------
# Conan configuration — only two build types. ASan and coverage are just
# CMake cache variables layered on top of the debug toolchain.
# ---------------------------------------------------------------------------
CONAN_STD := -s compiler.cppstd=23
CONAN_INSTALL_ARGS := $(CONAN_STD) --build=missing --lockfile=conan.lock

CONAN_BUILD_TYPE_debug   := Debug
CONAN_BUILD_TYPE_release := Release

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
STAMP_DIR := build/.stamps
COVERAGE_DIR := build/DebugCoverage
FORMAT_FILES := $(shell find include src tests -type f \( -name '*.hpp' -o -name '*.cpp' \))
TIDY_SOURCES := $(shell find src tests -type f -name '*.cpp')
LCOV_IGNORE_ERRORS_Linux := mismatch
LCOV_IGNORE_ERRORS_Darwin := format,format,mismatch,unsupported
LCOV_IGNORE_ERRORS ?= $(LCOV_IGNORE_ERRORS_$(UNAME_S))
LCOV_CAPTURE_ARGS := $(if $(LCOV_IGNORE_ERRORS),--ignore-errors $(LCOV_IGNORE_ERRORS),)

define require-tool
	command -v $(1) >/dev/null || { echo "$(1) not found"; exit 1; }
endef

# ---------------------------------------------------------------------------
# Conan lock file (lazy — regenerated when conanfile.py changes)
# ---------------------------------------------------------------------------
conan.lock: conanfile.py
	echo "Regenerating conan.lock..."
	$(CONAN) lock create . $(CONAN_STD)

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

# ---------------------------------------------------------------------------
# Conan profile and install targets
# ---------------------------------------------------------------------------
.PHONY: conan-profile
conan-profile: ## Detect the default Conan profile for this machine
	echo "Detecting Conan profile..."
	$(CONAN) profile detect --force

.PHONY: bootstrap
bootstrap: $(STAMP_DIR)/debug.stamp $(STAMP_DIR)/release.stamp ## Install Conan dependencies for all presets

# ---------------------------------------------------------------------------
# Build + test via workflow presets
# ---------------------------------------------------------------------------
CONAN_STAMP_debug    := debug
CONAN_STAMP_release  := release
CONAN_STAMP_asan     := debug
CONAN_STAMP_coverage := debug

CONAN_STAMP_lint     := debug

.PHONY: debug release asan coverage
debug:    ## Build via the debug workflow preset
release:  ## Build and test via the release workflow preset
asan:     ## Build and test via the asan workflow preset
coverage: ## Build, test, and generate LCOV coverage report

debug release asan: %: $(STAMP_DIR)/$$(CONAN_STAMP_%).stamp
	$(CMAKE) --workflow --preset $*

# ---------------------------------------------------------------------------
# Coverage report generation (appended after the workflow runs tests)
# ---------------------------------------------------------------------------
coverage: $(STAMP_DIR)/$$(CONAN_STAMP_coverage).stamp
	-find $(COVERAGE_DIR) -name '*.gcda' -delete
	$(CMAKE) --workflow --preset coverage
	$(call require-tool,$(LCOV))
	$(call require-tool,$(GENHTML))
	$(LCOV) --capture \
		--directory $(COVERAGE_DIR) \
		--base-directory $(abspath .) \
		--no-external \
		$(LCOV_CAPTURE_ARGS) \
		--output-file $(COVERAGE_DIR)/coverage.info
	rm -rf $(COVERAGE_DIR)/coverage-report
	$(GENHTML) $(COVERAGE_DIR)/coverage.info --output-directory $(COVERAGE_DIR)/coverage-report

# ---------------------------------------------------------------------------
# Lint and format
# ---------------------------------------------------------------------------
.PHONY: lint
lint: $(STAMP_DIR)/$$(CONAN_STAMP_lint).stamp ## Run clang-tidy against the debug compilation database
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
