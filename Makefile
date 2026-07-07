UNAME_S := $(shell uname -s)

COLOR_CYAN := \033[36m
COLOR_RED := \033[31m
COLOR_RESET := \033[0m

# Fail the recipe with a red ERROR message on stderr: $(DIE) "message". %b expands
# \n for multi-line messages. A sh -c one-liner (message as shell arg $0) rather than
# a $(call ...) macro because call splits its arguments on the commas messages contain.
# The subprocess cannot exit the recipe shell mid-sequence, so keep it the last
# command of its branch; its status then fails the recipe line.
DIE := sh -c 'printf "$(COLOR_RED)ERROR:$(COLOR_RESET) %b\n" "$$0" >&2; exit 1'

# Coverage uses two toolchains: Clang builds emit source-based profiles read by
# llvm-cov; GCC builds emit gcov data read by gcovr. coverage-report auto-selects
# based on which artifacts the build produced.
ifeq ($(UNAME_S),Darwin)
HOMEBREW_LLVM_PREFIX := $(shell brew --prefix llvm 2>/dev/null)
ifneq ($(HOMEBREW_LLVM_PREFIX),)
export PATH := $(HOMEBREW_LLVM_PREFIX)/bin:$(PATH)
endif
# xcrun resolves the LLVM tools from the active Xcode toolchain, matching the
# AppleClang that produced the .profraw files.
LLVM_PROFDATA ?= xcrun llvm-profdata
LLVM_COV ?= xcrun llvm-cov
else
LLVM_PROFDATA ?= llvm-profdata
LLVM_COV ?= llvm-cov
endif

GCOV_EXECUTABLE ?= gcov

.DEFAULT_GOAL := help

ifneq ($(VERBOSE),1)
.SILENT:
endif

.SECONDEXPANSION:

# ---------------------------------------------------------------------------
# Conan configuration — release gets its own profile state, coverage reuses the
# debug toolchain (its dependency graph is identical to Debug), and sanitize uses
# a dedicated profile plus a custom compiler.sanitizer setting (conan/settings_user.yml)
# so instrumented dependency binaries get a distinct package_id and are rebuilt
# rather than reused from cache.
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
# Floor is shared by both report paths. gcov and llvm-cov count lines differently
# (gcov 74.1%, llvm-cov 86.1% for the same code on CI), so it tracks the lower
# gcov figure: 74 is the tightest integer the gcov path clears (75 would fail).
COVERAGE_FAIL_UNDER ?= 74
COVERAGE_PROFRAW := $(COVERAGE_DIR)/profraw
COVERAGE_PROFDATA := $(COVERAGE_DIR)/coverage.profdata
# Report merged coverage for both binaries, restricted to first-party sources.
COVERAGE_OBJECTS := $(COVERAGE_DIR)/cpp_boilerplate -object $(COVERAGE_DIR)/split_test
COVERAGE_SOURCES := $(CURDIR)/src $(CURDIR)/include
FORMAT_SOURCES = $(shell find include src tests -type f \( -name '*.hpp' -o -name '*.cpp' \))
TIDY_SOURCES = $(shell find src tests -type f -name '*.cpp')

define require-tool
	command -v $(1) >/dev/null || $(DIE) "$(1) not found"
endef

# ---------------------------------------------------------------------------
# Conan lock file (lazy — regenerated when conanfile.py changes)
# ---------------------------------------------------------------------------
# --lockfile-clean drops entries the current graph no longer uses; without it,
# `conan lock create` merges into the existing lock and stale pins accumulate after
# a version bump or a removed dependency.
conan.lock: conanfile.py $(CONAN_PROFILE)
	echo "Regenerating conan.lock..."
	conan lock create . -pr=$(CONAN_PROFILE) --lockfile-clean --lockfile-out=conan.lock

# ---------------------------------------------------------------------------
# Conan install
# ---------------------------------------------------------------------------
$(STAMP_DIR)/debug.stamp: BUILD_TYPE = Debug
$(STAMP_DIR)/release.stamp: BUILD_TYPE = Release
$(STAMP_DIR)/debug.stamp $(STAMP_DIR)/release.stamp: conan.lock
	echo "Installing Conan dependencies ($(BUILD_TYPE))..."
	mkdir -p $(STAMP_DIR)
	conan install . -pr=$(CONAN_PROFILE) -s build_type=$(BUILD_TYPE) --build=missing --lockfile=conan.lock
	touch $@

$(STAMP_DIR)/sanitize.stamp: conan.lock conan/settings_user.yml profiles/sanitize profiles/sanitize-common
	echo "Installing Conan dependencies (sanitize)..."
	mkdir -p $(STAMP_DIR)
	# conan config install copies settings_user.yml into the Conan home, which would
	# silently overwrite a settings_user.yml another project put there. Refuse when a
	# different one exists; the file is small enough to merge by hand.
	installed="$$(conan config home)/settings_user.yml"; \
	if [ -f "$$installed" ] && ! cmp -s conan/settings_user.yml "$$installed"; then \
		$(DIE) "$$installed exists and differs from conan/settings_user.yml.\nMerge conan/settings_user.yml into it by hand (or remove it), then rerun."; \
	fi
	conan config install conan/
	conan install . -pr=profiles/sanitize --build=missing --lockfile=conan.lock
	touch $@

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------
.PHONY: help
help: ## Show this help message
	@awk 'BEGIN {FS = ":.*##"; printf "Usage: make [options] $(COLOR_CYAN)[target] ...$(COLOR_RESET)\n\n"} \
	/^[a-zA-Z_-]+:.*##/ {printf "  $(COLOR_CYAN)%-20s$(COLOR_RESET) %s\n", $$1, $$2}' \
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
	cmake --workflow --preset $@

# ---------------------------------------------------------------------------
# Coverage report generation
# ---------------------------------------------------------------------------
.PHONY: coverage-data-clean
coverage-data-clean:
	-rm -rf $(COVERAGE_PROFRAW) $(COVERAGE_PROFDATA) $(COVERAGE_DIR)/default.profraw
	-find $(COVERAGE_DIR) -name '*.gcda' -delete 2>/dev/null

.PHONY: coverage-report coverage-report-llvm coverage-report-gcov
coverage-report: coverage ## Generate an HTML coverage report and enforce the line floor
	$(call require-tool,python3)
	@if ls $(COVERAGE_PROFRAW)/*.profraw >/dev/null 2>&1; then \
		$(MAKE) --no-print-directory coverage-report-llvm; \
	else \
		$(MAKE) --no-print-directory coverage-report-gcov; \
	fi

# Clang source-based coverage via llvm-cov (HTML + lcov + line floor).
coverage-report-llvm:
	$(LLVM_PROFDATA) merge -sparse $(COVERAGE_PROFRAW)/*.profraw -o $(COVERAGE_PROFDATA)
	$(LLVM_COV) show $(COVERAGE_OBJECTS) -instr-profile=$(COVERAGE_PROFDATA) \
		-format=html -output-dir=$(COVERAGE_DIR)/coverage-report $(COVERAGE_SOURCES)
	$(LLVM_COV) export -format=lcov $(COVERAGE_OBJECTS) -instr-profile=$(COVERAGE_PROFDATA) \
		$(COVERAGE_SOURCES) > $(COVERAGE_DIR)/coverage.lcov
	$(LLVM_COV) report $(COVERAGE_OBJECTS) -instr-profile=$(COVERAGE_PROFDATA) $(COVERAGE_SOURCES)
	$(LLVM_COV) export -summary-only $(COVERAGE_OBJECTS) -instr-profile=$(COVERAGE_PROFDATA) \
		$(COVERAGE_SOURCES) | python3 -c 'import json, sys; \
		pct = json.load(sys.stdin)["data"][0]["totals"]["lines"]["percent"]; floor = float(sys.argv[1]); \
		print("line coverage %.1f%% (floor %s%%)" % (pct, sys.argv[1])); \
		sys.exit(0 if pct >= floor else 1)' $(COVERAGE_FAIL_UNDER)

# GCC gcov coverage via gcovr (HTML + Cobertura + line floor).
coverage-report-gcov:
	mkdir -p $(COVERAGE_DIR)/coverage-report
	python3 -m gcovr --root . --gcov-executable "$(GCOV_EXECUTABLE)" \
		--filter 'include/' --filter 'src/' --exclude 'tests/' \
		--html-details $(COVERAGE_DIR)/coverage-report/index.html \
		--cobertura $(COVERAGE_DIR)/coverage.xml \
		--txt-summary --fail-under-line $(COVERAGE_FAIL_UNDER) \
		$(COVERAGE_DIR)

# ---------------------------------------------------------------------------
# Lint and format
# ---------------------------------------------------------------------------
.PHONY: lint
lint: $(STAMP_DIR)/debug.stamp ## Run clang-tidy against the debug compilation database
	$(call require-tool,clang-tidy)
	cmake --preset debug
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
lock: ## Force-regenerate conan.lock from conanfile.py
	echo "Regenerating conan.lock..."
	conan lock create . -pr=$(CONAN_PROFILE) --lockfile-clean --lockfile-out=conan.lock

# Scope: validates the graph resolved by the default profile only. If requirements()
# ever gains platform-conditional requires (the pattern its comment advertises), this
# check needs to run once per platform profile to cover the full graph.
.PHONY: lock-check
lock-check: ## Fail if conan.lock is out of date with conanfile.py (used by CI)
	tmp=$$(mktemp); \
	conan lock create . -pr=$(CONAN_PROFILE) --lockfile-clean --lockfile-out=$$tmp >/dev/null 2>&1 \
		|| { rm -f $$tmp; $(DIE) "conan lock create failed"; }; \
	if diff conan.lock $$tmp >/dev/null; then \
		rm -f $$tmp; echo "conan.lock is up to date"; \
	else \
		diff conan.lock $$tmp || true; rm -f $$tmp; \
		$(DIE) "conan.lock is stale; run 'make lock' and commit the result"; \
	fi

.PHONY: clean
clean: ## Remove generated build artifacts and Conan preset files
	echo "Removing generated artifacts..."
	rm -rf build/ compile_commands.json CMakeUserPresets.json ConanPresets.json
