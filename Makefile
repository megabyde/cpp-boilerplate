LLVM_PREFIX ?= $(shell brew --prefix llvm 2>/dev/null || true)
LLVM_BIN := $(if $(wildcard $(LLVM_PREFIX)/bin/clang-format),$(LLVM_PREFIX)/bin,)
UNAME_S := $(shell uname -s)

CONAN ?= conan
CMAKE ?= cmake
CTEST ?= ctest
LCOV ?= lcov
GENHTML ?= genhtml

CLANG_FORMAT ?= $(if $(LLVM_BIN),$(LLVM_BIN)/clang-format,clang-format)
CLANG_TIDY ?= $(if $(LLVM_BIN),$(LLVM_BIN)/clang-tidy,clang-tidy)

ifneq ($(VERBOSE),1)
.SILENT:
endif

CONAN_INSTALL_ARGS ?= -s compiler.cppstd=23 --build=missing --lockfile=conan.lock
FORMAT_FILES := $(shell find include src tests -type f \( -name '*.hpp' -o -name '*.cpp' \))
TIDY_SOURCES := $(shell find src tests -type f -name '*.cpp')
CONAN_INPUTS := conanfile.py conan.lock
CONAN_BUILD_DIR_debug := build/debug
CONAN_BUILD_DIR_release := build/release
CONAN_BUILD_DIR_asan := build/debug-asan
CONAN_BUILD_DIR_coverage := build/debug-coverage
CONAN_STAMP_debug := $(CONAN_BUILD_DIR_debug)/.conan.stamp
CONAN_STAMP_release := $(CONAN_BUILD_DIR_release)/.conan.stamp
CONAN_STAMP_asan := $(CONAN_BUILD_DIR_asan)/.conan.stamp
CONAN_STAMP_coverage := $(CONAN_BUILD_DIR_coverage)/.conan.stamp
CONAN_STAMPS := $(CONAN_STAMP_debug) $(CONAN_STAMP_release) $(CONAN_STAMP_asan) $(CONAN_STAMP_coverage)
CONAN_BUILD_TYPE_debug := Debug
CONAN_BUILD_TYPE_release := Release
CONAN_BUILD_TYPE_asan := Debug
CONAN_BUILD_TYPE_coverage := Debug
CONAN_OPTIONS_asan := -o '&:asan=True'
CONAN_OPTIONS_coverage := -o '&:coverage=True'
RUN_TESTS_release := 1
RUN_TESTS_asan := 1
LCOV_IGNORE_ERRORS_Linux := mismatch
LCOV_IGNORE_ERRORS_Darwin := format,format,mismatch,unsupported
LCOV_IGNORE_ERRORS ?= $(LCOV_IGNORE_ERRORS_$(UNAME_S))
LCOV_CAPTURE_ARGS := $(if $(LCOV_IGNORE_ERRORS),--ignore-errors $(LCOV_IGNORE_ERRORS),)

define require-tool
	command -v $(1) >/dev/null || { echo "$(1) not found"; exit 1; }
endef

.PHONY: help
help: ## Show available targets
	printf "Available targets:\n"
	sed -n 's/^\([[:alnum:]_%.-][^:]*\):.*##[[:space:]]*\(.*\)$$/\1\t\2/p' $(MAKEFILE_LIST) | \
	while IFS=$$(printf '\t') read -r target description; do \
		printf "  %-20s %s\n" "$$target" "$$description"; \
	done

.PHONY: conan-profile
conan-profile: ## Detect the default Conan profile for this machine
	echo "Detecting Conan profile..."
	$(CONAN) profile detect --force

conan-debug: $(CONAN_STAMP_debug) ## Generate Conan presets and toolchain files for the debug preset
conan-release: $(CONAN_STAMP_release) ## Generate Conan presets and toolchain files for the release and ci presets
conan-asan: $(CONAN_STAMP_asan) ## Generate Conan presets and toolchain files for the asan preset
conan-coverage: $(CONAN_STAMP_coverage) ## Generate Conan presets and toolchain files for the coverage preset

$(CONAN_STAMP_debug): CONAN_PRESET_NAME = debug
$(CONAN_STAMP_release): CONAN_PRESET_NAME = release
$(CONAN_STAMP_asan): CONAN_PRESET_NAME = asan
$(CONAN_STAMP_coverage): CONAN_PRESET_NAME = coverage

$(CONAN_STAMPS): %/.conan.stamp: $(CONAN_INPUTS)
	echo "Installing Conan dependencies ($(CONAN_PRESET_NAME))..."
	$(CONAN) install . -s build_type=$(CONAN_BUILD_TYPE_$(CONAN_PRESET_NAME)) $(CONAN_OPTIONS_$(CONAN_PRESET_NAME)) $(CONAN_INSTALL_ARGS)
	touch $@

.PHONY: bootstrap
bootstrap: conan-debug conan-release ## Generate Conan presets for the public debug, release, and ci presets

.PHONY: build-debug build-release build-asan build-coverage
build-debug build-release build-asan build-coverage: build-%: conan-%
	echo "Configuring CMake ($*)..."
	$(CMAKE) --preset $* $(CMAKE_CONFIGURE_ARGS_$*)
	echo "Building ($*)..."
	$(CMAKE) --build --preset $*

.PHONY: debug release asan
debug release asan: %: build-%
	$(if $(RUN_TESTS_$@),echo "Running tests ($@)..."; $(CTEST) --preset $@)

.PHONY: ci
ci: conan-release ## Run the public CI workflow preset
	echo "Running workflow (ci)..."
	$(CMAKE) --workflow --preset ci

.PHONY: test-debug test-release test-asan test-coverage
test-debug test-release test-asan test-coverage: test-%: build-%
	echo "Running tests ($*)..."
	$(CTEST) --preset $*

.PHONY: coverage
coverage: build-coverage ## Generate an LCOV report under build/debug-coverage/coverage-report
	echo "Generating coverage report..."
	$(call require-tool,$(LCOV))
	$(call require-tool,$(GENHTML))
	find build/debug-coverage -name '*.gcda' -delete
	echo "Running tests (coverage)..."
	$(CTEST) --preset coverage
	$(LCOV) --capture \
		--directory build/debug-coverage \
		--base-directory $(abspath .) \
		--no-external \
		$(LCOV_CAPTURE_ARGS) \
		--output-file build/debug-coverage/coverage.info
	rm -rf build/debug-coverage/coverage-report
	$(GENHTML) build/debug-coverage/coverage.info --output-directory build/debug-coverage/coverage-report

.PHONY: lint
lint: conan-debug ## Run clang-tidy against the debug compilation database
	echo "Configuring CMake (debug)..."
	$(CMAKE) --preset debug
	echo "Running clang-tidy..."
	$(call require-tool,$(CLANG_TIDY))
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

.PHONY: lock
lock: ## Regenerate conan.lock from conanfile.py
	echo "Regenerating conan.lock..."
	$(CONAN) lock create . -s compiler.cppstd=23 -s build_type=Debug
	$(CONAN) lock create . -s compiler.cppstd=23 -s build_type=Release --lockfile=conan.lock --lockfile-out=conan.lock

.PHONY: clean
clean: ## Remove generated build artifacts and Conan preset files
	echo "Removing generated artifacts..."
	rm -rf build/ ConanPresets.json compile_commands.json CMakeUserPresets.json
