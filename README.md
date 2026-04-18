# C++ Boilerplate

[![Build](https://github.com/megabyde/cpp-boilerplate/actions/workflows/build.yml/badge.svg)](https://github.com/megabyde/cpp-boilerplate/actions/workflows/build.yml)
[![C++23](https://img.shields.io/badge/C%2B%2B-23-blue.svg)](https://en.cppreference.com/w/cpp/23)
[![CMake](https://img.shields.io/badge/CMake-3.28%2B-064F8C.svg)](https://cmake.org)
[![Conan](https://img.shields.io/badge/Conan-2.x-6699CB.svg)](https://conan.io)
[![License](https://img.shields.io/badge/license-Unlicense-green.svg)](LICENSE)

## Overview

A modern C++23 project template demonstrating end-to-end toolchain integration: Conan 2.5+
dependency management, CMake presets, testing, sanitizers, coverage, CI, and IDE setup.

This repository uses:

- [CMake](https://cmake.org) presets and workflow presets as the public build interface
- [Conan 2](https://conan.io) for dependency management
- [spdlog](https://github.com/gabime/spdlog) via Conan as the sample compiled dependency
- [GoogleTest](https://github.com/google/googletest) via Conan

The checked-in presets are the source of truth. [`Makefile`](Makefile) is a thin convenience
wrapper around `make bootstrap` plus the public CMake presets and workflows.

## Prerequisites

- CMake 3.28+
- Conan 2.5+
- Ninja or GNU Make on Unix-like systems
- A compiler and standard library with working C++23 support
  - GCC 13+
  - LLVM Clang 17+
  - Apple Clang 17+ recommended

Conan chooses the CMake generator for you:

- `Ninja` on Unix-like systems when it is available
- `Unix Makefiles` on Unix-like systems when `ninja` is not installed

This boilerplate currently supports macOS and Linux.

## Configure, build, and test

### Quick start

```console
git clone https://github.com/megabyde/cpp-boilerplate.git
cd cpp-boilerplate
make bootstrap
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

### Why CMakePresets.json includes ConanPresets.json

The checked-in `CMakePresets.json` owns the public preset names. Conan owns toolchain details. The
generated `ConanPresets.json` is an implementation detail, not an interface; `make bootstrap` is
the one-time per-clone step that materializes it.

### Sanitizers

```console
make sanitize
```

This uses a dedicated sanitizer build tree under `build/sanitize`.

> [!NOTE]
> Conan owns the dependency graph, generator, toolchain, and ABI settings. If you switch the Conan
> configuration, rerun `make bootstrap` or the matching public `make` target and keep using the
> same public CMake preset names.

> [!NOTE]
> Sanitizer instrumentation currently applies to first-party code only. Conan dependencies are built
> with the selected debug profile, not a dedicated sanitizer profile overlay.

### Tests

Tests are controlled by CMake's built-in `BUILD_TESTING` option from `include(CTest)`. This
project leaves it at the default `ON`, so the `release`, `sanitize`, and `coverage` workflows run the
test suite by default.

## Public presets

- Configure presets: `debug`, `release`, `sanitize`, `coverage`
- Build presets: `debug`, `release`, `sanitize`, `coverage`
- Test presets: `debug`, `release`, `sanitize`, `coverage`
- Workflow presets: `debug`, `release`, `sanitize`, `coverage`

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

Generate a gcovr Cobertura report and HTML report with:

```console
make coverage
```

This writes:

- `build/coverage/coverage.xml`
- `build/coverage/coverage-report/index.html`

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
- `CMakePresets.json`: project-owned public presets and workflows
