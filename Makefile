LLVM_PREFIX ?= $(shell brew --prefix llvm 2>/dev/null || true)
LLVM_BIN := $(if $(wildcard $(LLVM_PREFIX)/bin/clang-format),$(LLVM_PREFIX)/bin,)
export PATH := $(if $(LLVM_BIN),$(LLVM_BIN):$(PATH),$(PATH))

CONAN ?= conan
CMAKE ?= cmake
CTEST ?= ctest
CLANG_FORMAT ?= $(if $(LLVM_BIN),$(LLVM_BIN)/clang-format,clang-format)
CLANG_TIDY ?= $(if $(LLVM_BIN),$(LLVM_BIN)/clang-tidy,clang-tidy)
CONAN_INSTALL_ARGS ?= --build=missing
PRESETS := debug release
BUILD_TYPE_debug := Debug
BUILD_TYPE_release := Release
FORMAT_FILES := $(shell find include src tests -type f \( -name '*.hpp' -o -name '*.cpp' \))
TIDY_SOURCES := $(shell find src tests -type f -name '*.cpp')

.PHONY: help
help: ## Show available targets
	@printf "Available targets:\n"
	@sed -n 's/^\([[:alnum:]_%.-][^:]*\):.*##[[:space:]]*\(.*\)$$/\1\t\2/p' $(MAKEFILE_LIST) | \
	while IFS=$$(printf '\t') read -r target description; do \
		printf "  %-24s %s\n" "$$target" "$$description"; \
	done

.PHONY: conan-profile
conan-profile: ## Detect the default Conan profile for this machine
	$(CONAN) profile detect --force

.PHONY: conan-%
conan-%: ## Install Conan dependencies for a preset, e.g. make conan-debug
	$(CONAN) install . \
		--output-folder=build/conan/$* \
		$(CONAN_INSTALL_ARGS) \
		-s build_type=$(BUILD_TYPE_$*)

.PHONY: configure-%
configure-%: ## Configure CMake for a preset, e.g. make configure-debug
	$(CMAKE) --preset $*
	$(MAKE) link-compile-commands-$*

.PHONY: link-compile-commands-%
link-compile-commands-%: ## Symlink preset compile_commands.json to the project root
	ln -sfn build/$*/compile_commands.json compile_commands.json

.PHONY: build-%
build-%: ## Build a preset, e.g. make build-debug
	$(CMAKE) --build --preset $*

.PHONY: test-%
test-%: ## Run tests for a preset, e.g. make test-debug
	$(CTEST) --preset $*

.PHONY: format
format: ## Format C++ sources in place with clang-format
	@command -v $(CLANG_FORMAT) >/dev/null || { echo "$(CLANG_FORMAT) not found"; exit 1; }
	@$(CLANG_FORMAT) -i $(FORMAT_FILES)

.PHONY: format-check
format-check: ## Fail if C++ sources are not clang-format clean
	@command -v $(CLANG_FORMAT) >/dev/null || { echo "$(CLANG_FORMAT) not found"; exit 1; }
	@$(CLANG_FORMAT) --dry-run --Werror $(FORMAT_FILES)

.PHONY: lint
lint: ## Run clang-tidy against the debug compilation database
	@command -v $(CLANG_TIDY) >/dev/null || { echo "$(CLANG_TIDY) not found"; exit 1; }
	$(MAKE) conan-debug configure-debug
	@$(CLANG_TIDY) -p build/debug $(TIDY_SOURCES)

.PHONY: debug
debug: ## Install, configure, build, and test the debug preset

.PHONY: release
release: ## Install, configure, build, and test the release preset

$(PRESETS): %: conan-% configure-% build-% test-% ## Install, configure, build, and test a preset

.PHONY: ci
ci: release ## CI entry point; currently equivalent to release
