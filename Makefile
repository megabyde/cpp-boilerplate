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

CONAN_INSTALL_ARGS ?= --build=missing
PRESETS := debug release
BUILD_DIR_debug := build/debug
BUILD_DIR_release := build/release
BUILD_TYPE_debug := Debug
BUILD_TYPE_release := Release
CMAKE_PRESET_debug := debug
CMAKE_PRESET_release := release
CMAKE_CONFIGURE_ARGS_debug := -DCPP_BOILERPLATE_ENABLE_COVERAGE=ON
CMAKE_CONFIGURE_ARGS_release :=
LCOV_IGNORE_ERRORS_Linux := mismatch
LCOV_IGNORE_ERRORS_Darwin := format,format,mismatch,unsupported
LCOV_IGNORE_ERRORS ?= $(LCOV_IGNORE_ERRORS_$(UNAME_S))
LCOV_CAPTURE_ARGS := $(if $(LCOV_IGNORE_ERRORS),--ignore-errors $(LCOV_IGNORE_ERRORS),)

STAMP_FILES := $(foreach preset,$(PRESETS),$(BUILD_DIR_$(preset))/.conan.stamp $(BUILD_DIR_$(preset))/.cmake.stamp)

CONAN_INPUTS := conanfile.py conan.lock
CONFIGURE_INPUTS := CMakeLists.txt CMakePresets.json
FORMAT_FILES := $(shell find include src tests -type f \( -name '*.hpp' -o -name '*.cpp' \))
TIDY_SOURCES := $(shell find src tests -type f -name '*.cpp')

define require-tool
	@command -v $(1) >/dev/null || { echo "$(1) not found"; exit 1; }
endef

.PRECIOUS: $(STAMP_FILES)

.PHONY: help
help: ## Show available targets
	@printf "Available targets:\n"
	@sed -n 's/^\([[:alnum:]_%.-][^:]*\):.*##[[:space:]]*\(.*\)$$/\1\t\2/p' $(MAKEFILE_LIST) | \
	while IFS=$$(printf '\t') read -r target description; do \
		printf "  %-24s %s\n" "$$target" "$$description"; \
	done

.PHONY: conan-profile
conan-profile: ## Detect the default Conan profile for this machine
	@echo "Detecting Conan profile..."
	$(CONAN) profile detect --force

.PHONY: conan-%
conan-%: build/%/.conan.stamp ## Install Conan dependencies for a preset, e.g. make conan-debug
	@:

$(BUILD_DIR_debug)/.conan.stamp $(BUILD_DIR_release)/.conan.stamp: $(CONAN_INPUTS)
	@echo "Installing Conan dependencies ($(notdir $(@D)))..."
	mkdir -p $(@D)
	$(CONAN) install . \
		--output-folder=$(@D) \
		$(CONAN_INSTALL_ARGS) \
		-c tools.cmake.cmaketoolchain:generator=Ninja \
		--lockfile=conan.lock \
		-s build_type=$(BUILD_TYPE_$(notdir $(@D)))
	touch $@

.PHONY: configure-%
configure-%: build/%/.cmake.stamp ## Configure CMake for a preset, e.g. make configure-debug
	@:

$(BUILD_DIR_debug)/.cmake.stamp $(BUILD_DIR_release)/.cmake.stamp: $(CONFIGURE_INPUTS)
$(BUILD_DIR_debug)/.cmake.stamp: $(BUILD_DIR_debug)/.conan.stamp
	@echo "Configuring CMake (debug)..."
	$(CMAKE) --preset $(CMAKE_PRESET_debug) $(CMAKE_CONFIGURE_ARGS_debug)
	touch $@

$(BUILD_DIR_release)/.cmake.stamp: $(BUILD_DIR_release)/.conan.stamp
	@echo "Configuring CMake (release)..."
	$(CMAKE) --preset $(CMAKE_PRESET_release) $(CMAKE_CONFIGURE_ARGS_release)
	touch $@

.PHONY: build-%
build-%: build/%/.cmake.stamp ## Build a preset, e.g. make build-debug
	@echo "Building ($*)..."
	$(CMAKE) --build --preset $(CMAKE_PRESET_$*)

.PHONY: test-%
test-%: build-% ## Run tests for a preset, e.g. make test-debug
	@echo "Running tests ($*)..."
	$(CTEST) --preset $(CMAKE_PRESET_$*)

.PHONY: format
format: ## Format C++ sources in place with clang-format
	@echo "Formatting C++ sources..."
	$(call require-tool,$(CLANG_FORMAT))
	$(CLANG_FORMAT) -i $(FORMAT_FILES)

.PHONY: format-check
format-check: ## Fail if C++ sources are not clang-format clean
	@echo "Checking C++ formatting..."
	$(call require-tool,$(CLANG_FORMAT))
	$(CLANG_FORMAT) --dry-run --Werror $(FORMAT_FILES)

.PHONY: coverage
coverage: build-debug ## Generate an LCOV report under build/debug/coverage-report
	@echo "Generating coverage report..."
	$(call require-tool,$(LCOV))
	$(call require-tool,$(GENHTML))
	find $(BUILD_DIR_debug) -name '*.gcda' -delete
	$(CTEST) --preset $(CMAKE_PRESET_debug)
	$(LCOV) --capture \
		--directory $(BUILD_DIR_debug) \
		--base-directory $(abspath .) \
		--no-external \
		$(LCOV_CAPTURE_ARGS) \
		--output-file $(BUILD_DIR_debug)/coverage.info
	rm -rf $(BUILD_DIR_debug)/coverage-report
	$(GENHTML) $(BUILD_DIR_debug)/coverage.info --output-directory $(BUILD_DIR_debug)/coverage-report

.PHONY: lint
lint: configure-debug ## Run clang-tidy against the debug compilation database
	@echo "Running clang-tidy..."
	$(call require-tool,$(CLANG_TIDY))
	$(CLANG_TIDY) -p $(BUILD_DIR_debug) $(TIDY_SOURCES)

.PHONY: clean
clean: ## Remove all build artifacts
	@echo "Removing build artifacts..."
	rm -rf build/

.PHONY: lock
lock: ## Regenerate conan.lock from conanfile.py
	@echo "Regenerating conan.lock..."
	$(CONAN) lock create . -s build_type=Debug
	$(CONAN) lock create . -s build_type=Release --lockfile=conan.lock --lockfile-out=conan.lock

.PHONY: debug
debug: ## Install, configure, build, and test the debug preset

.PHONY: release
release: ## Install, configure, build, and test the release preset

$(PRESETS): %: test-% ## Install, configure, build, and test a preset
