# C++ Boilerplate

[![Build](https://github.com/megabyde/cpp-boilerplate/actions/workflows/build.yml/badge.svg)](https://github.com/megabyde/cpp-boilerplate/actions/workflows/build.yml)
[![C++23](https://img.shields.io/badge/C%2B%2B-23-blue.svg)](https://en.cppreference.com/w/cpp/23)
[![CMake](https://img.shields.io/badge/CMake-3.28%2B-064F8C.svg)](https://cmake.org)
[![Conan](https://img.shields.io/badge/Conan-2.x-6699CB.svg)](https://conan.io)
[![License](https://img.shields.io/badge/license-Unlicense-green.svg)](LICENSE)

## Overview

A modern C++23 project template demonstrating end-to-end toolchain integration: Conan 2.25+
dependency management, CMake presets, testing, sanitizers, coverage, CI, and IDE setup.

This repository uses:

- [CMake](https://cmake.org) configure, build, and test presets as the public build interface
- [Conan 2](https://conan.io) for dependency management
- [spdlog](https://github.com/gabime/spdlog) via Conan as the sample compiled dependency
- [GoogleTest](https://github.com/google/googletest) via Conan

The checked-in presets are the source of truth. [`Makefile`](Makefile) is a thin convenience
wrapper around `make bootstrap` plus the public CMake presets.

## Prerequisites

- [CMake](https://cmake.org/download/) 3.28+
- [Conan](https://docs.conan.io/2/installation.html) 2.25+ (for the `CMakeConfigDeps` generator)
- [Ninja](https://ninja-build.org/) (required on Windows; GNU Make also works on Unix)
- A compiler and standard library with working C++23 support
  - [GCC](https://gcc.gnu.org/) 13+
  - [LLVM Clang](https://llvm.org/) 17+
  - [Apple Clang](https://developer.apple.com/xcode/) 17+ recommended
  - [MSVC](https://visualstudio.microsoft.com/) 2022 (17.10+) on Windows

Conan chooses the CMake generator for you:

- `Ninja` on Unix-like systems when it is available
- `Unix Makefiles` on Unix-like systems when `ninja` is not installed

This boilerplate supports Linux, macOS, and Windows.

## Configure, build, and test

### Quick start

```console
git clone https://github.com/megabyde/cpp-boilerplate.git
cd cpp-boilerplate
make bootstrap          # one-time; generates ConanPresets.json
make debug
```

Other local convenience targets:

```console
make release
make sanitize
make coverage
make lint
make format-check
```

### Windows

The `Makefile` is a Unix convenience wrapper. On Windows, drive Conan and the CMake
presets directly from a shell with the MSVC environment loaded (a Developer
PowerShell, or any shell after `vcvarsall`):

```console
conan install . -pr=profiles/default -s build_type=Release --build=missing --lockfile=conan.lock
cmake --workflow --preset release
```

`cmake --workflow --preset <name>` runs configure, build, and test in one step; it
is what the `make` targets call on Unix too. The `sanitize` and `coverage` presets
are Unix-only.

### Why CMakePresets.json includes ConanPresets.json

The checked-in `CMakePresets.json` owns the public preset names. Conan owns toolchain details. The
generated `ConanPresets.json` is an implementation detail, not an interface; `make bootstrap` is
the one-time per-clone step that materializes it.

### Sanitizers (ASAN + UBSAN)

```console
make sanitize
```

This uses a dedicated sanitizer build tree (Conan names it `build/debug-addressundefinedbehavior`
after the build type and `compiler.sanitizer` setting) and a Conan sanitize profile so
dependencies are rebuilt with matching instrumentation, not linked from their plain
(uninstrumented) Debug binaries.

Three modes are provided, showcasing Conan profile inheritance. Each mode profile inherits a
shared base, [`profiles/sanitize-common`](profiles/sanitize-common) (which pulls in
`profiles/default`, sets `Debug`, and carries the common instrumentation flags and `[runenv]`),
and appends its own `-fsanitize` flags:

- `sanitize` — combined ASan + UBSan ([`profiles/sanitize`](profiles/sanitize)); driven by
  `make sanitize` and CI.
- `sanitize-asan` — AddressSanitizer only ([`profiles/sanitize-asan`](profiles/sanitize-asan)).
- `sanitize-ubsan` — UndefinedBehaviorSanitizer only
  ([`profiles/sanitize-ubsan`](profiles/sanitize-ubsan)).

`make sanitize` runs the combined mode. The single-mode presets are runnable directly once
their instrumented dependencies are installed (all three share `conan.lock`):

```console
conan config install conan/  # once; installs conan/settings_user.yml, i.e. the compiler.sanitizer setting (bootstrap-sanitize does this too)
conan install . -pr=profiles/sanitize-asan --build=missing --lockfile=conan.lock
cmake --workflow --preset sanitize-asan
```

Each mode gets its own `package_id` and build tree (`build/debug-address`,
`build/debug-undefinedbehavior`, `build/debug-addressundefinedbehavior`).

ASan/UBSan runtime options (`halt_on_error`, `print_stacktrace`, and related checks) live in
`profiles/sanitize-common` under `[runenv]` (inherited by every mode). Conan injects them into
the generated per-mode test preset, which the public `sanitize*` test preset inherits, so
`ctest`/`cmake --workflow` runs the instrumented tests with those options — a single source of
truth, no duplication in `CMakePresets.json`.

That separation relies on a custom `compiler.sanitizer` setting defined in
[`conan/settings_user.yml`](conan/settings_user.yml). The setting gives instrumented
dependency binaries a distinct Conan `package_id`; the sanitizer flags themselves
travel through the profile's `tools.build:*` conf, which does not affect `package_id`.
Without the setting, `--build=missing` would silently reuse the uninstrumented Debug
binaries.

`make bootstrap-sanitize` installs that file into your Conan home with
`conan config install conan/` (the repository's `conan/` directory) before resolving
dependencies. This is a global Conan
side effect: it adds the `compiler.sanitizer` subsetting (default `null`, omitted from
`package_id`) and does not change non-sanitize builds.

The default `make bootstrap` does not install sanitizer-instrumented dependencies. Run
`make bootstrap-sanitize` or `make sanitize` when you need them.

First-party targets are instrumented by the same Conan toolchain (the profile's
`tools.build:*` flags reach the consumer), so the `sanitize` preset does not also set
the CMake `ENABLE_SANITIZERS` option, which would double the flags. `ENABLE_SANITIZERS`
remains a standalone option for instrumenting first-party code without the Conan
profile, e.g. `cmake --preset debug -DENABLE_SANITIZERS=ON` (dependencies stay
uninstrumented in that mode).

> [!NOTE]
> Conan owns the dependency graph, generator, toolchain, and ABI settings. If you switch the Conan
> configuration, rerun `make bootstrap` or the matching public `make` target and keep using the
> same public CMake preset names.

### Tests

Tests are controlled by CMake's built-in `BUILD_TESTING` option from `include(CTest)`. This
project leaves it at the default `ON`, so `make debug`, `make release`, `make sanitize`, and
`make coverage` all run the gtest suite.

## Public presets

- Configure presets: `debug`, `release`, `sanitize`, `sanitize-asan`, `sanitize-ubsan`, `coverage`
- Build presets: `debug`, `release`, `sanitize`, `sanitize-asan`, `sanitize-ubsan`, `coverage`
- Test presets: `debug`, `release`, `sanitize`, `sanitize-asan`, `sanitize-ubsan`, `coverage`
- Workflow presets: `debug`, `release`, `sanitize`, `sanitize-asan`, `sanitize-ubsan`, `coverage` (configure + build + test)

The Conan-generated `conan-*` presets are internal implementation details and are not the public
interface for developers or CI.

## Dependency lock file

`conan.lock` pins the exact dependency graph for reproducible builds. To update dependencies:

1. Edit version pins in `conanfile.py`.
2. Regenerate the lock file with `make lock`.
3. Run the appropriate `make` target to verify.
4. Commit both `conanfile.py` and `conan.lock`.

## Formatting and linting

```console
make format
make format-check
make lint
```

## Coverage

Build, test, and generate an HTML coverage report with an enforced line floor:

```console
make coverage-report
```

Coverage supports both compilers and selects the matching toolchain automatically
from the build artifacts:

- **Clang / AppleClang**: source-based instrumentation reported by `llvm-cov`.
  Writes `coverage-report/index.html` and `coverage.lcov` under `build/coverage/`.
- **GCC**: `gcov` instrumentation reported by `gcovr` (`pip install gcovr`). Writes
  `coverage-report/index.html` and `coverage.xml` under `build/coverage/`.

The report fails if line coverage falls below `COVERAGE_FAIL_UNDER` (default 74;
override with `make coverage-report COVERAGE_FAIL_UNDER=80`). `gcov` and `llvm-cov`
count lines differently (gcov reports lower), so the floor tracks the gcov figure
so both paths pass.

## Install

`cmake --install` installs the application binary to `<prefix>/bin`. Only the executable is
installed; the static library is an internal build artifact and is deliberately not installed
or exported.

```console
$ cmake --workflow --preset release
$ cmake --install build/release --prefix /path/to/prefix
$ /path/to/prefix/bin/cpp_boilerplate
[2026-06-30 20:46:16.431] [info] cpp-boilerplate 0.1.0 starting
[2026-06-30 20:46:16.431] [info] field 0: alpha
[2026-06-30 20:46:16.431] [info] field 1: beta
[2026-06-30 20:46:16.431] [info] field 2: gamma
[2026-06-30 20:46:16.431] [info] done
```

## IDE setup

### VS Code

VS Code with CMake Tools will discover the checked-in public presets automatically after Conan
generates `ConanPresets.json`. Run `make bootstrap` first.

Then open the folder, accept the recommended extensions, and select the matching public preset.
For the checked-in launch configuration, choose the target you want in the CMake Tools sidebar and
start `Debug: CMake Target`. F5 builds the selected debug target and launches it from `build/debug`.

### CLion

CLion can use the same public presets. Run `make bootstrap` first, then in CLion:

1. Open the project root
2. Select the `debug`, `release`, `sanitize`, or `coverage` preset as the active CMake profile
3. Reload CMake

> [!NOTE]
> No IDE-specific task files are required for the build. The presets are the source of truth.
> `debug`, `sanitize`, and `coverage` each use their own build tree, so switching between them does not
> require forcing a fresh reconfigure.

## Layout

- `include/`: public headers
- `src/`: application sources
- `tests/`: unit tests
- `conanfile.py`: Conan dependency definition
- `conan/settings_user.yml`: custom `compiler.sanitizer` setting for instrumented dependency builds
- `profiles/`: Conan profiles (`default`; `sanitize-common` base inherited by `sanitize`, `sanitize-asan`, `sanitize-ubsan`)
- `CMakePresets.json`: project-owned public presets
