# C++ Boilerplate

[![Build](https://github.com/megabyde/cpp-boilerplate/actions/workflows/build.yml/badge.svg)](https://github.com/megabyde/cpp-boilerplate/actions/workflows/build.yml)
[![C++23](https://img.shields.io/badge/C%2B%2B-23-blue.svg)](https://en.cppreference.com/w/cpp/23)
[![CMake](https://img.shields.io/badge/CMake-3.28%2B-064F8C.svg)](https://cmake.org)
[![Conan](https://img.shields.io/badge/Conan-2.x-6699CB.svg)](https://conan.io)
[![License](https://img.shields.io/badge/license-Unlicense-green.svg)](LICENSE)

## Overview

A modern C++23 project template demonstrating end-to-end toolchain integration: Conan 2 dependency
management, CMake presets, multi-configuration builds, testing, sanitizers, coverage, CI, and IDE
seteup.

This repository uses:

- [CMake](https://cmake.org) presets and workflow presets as the public build interface
- [Conan 2](https://conan.io) for dependency management
- [Boost](https://www.boost.org) via Conan for portable utility libraries
- [GoogleTest](https://github.com/google/googletest) via Conan

The sample code intentionally stays small, but it demonstrates a few C++23-friendly defaults:

- `std::string_view` for lightweight input handling
- `std::views::transform` in the sample utility pipeline without adding extra template machinery

The project keeps the public presets in the repository and lets Conan generate the toolchain and its
internal presets:

- the project owns [`CMakePresets.json`](CMakePresets.json)
- Conan generates `ConanPresets.json`
- the public presets (`debug`, `release`, `asan`, `coverage`) inherit from Conan's internal
  presets

The checked-in presets are the source of truth. The [`Makefile`](Makefile) is only a thin
convenience wrapper around `conan install` plus the public CMake presets and workflows.

This repository uses Conan's `CMakeConfigDeps` generator directly.

## Prerequisites

- CMake 3.28+
- Conan 2
- Ninja or GNU Make on Unix-like systems
- A compiler and standard library with working C++23 support
  - GCC 13+
  - LLVM Clang 17+
  - Apple Clang 17+ recommended

> [!IMPORTANT]
> If you are on a very new Apple Clang release, make sure your Conan installation and settings are
> up to date before running `conan profile detect`.

Conan chooses the CMake generator for you:

- `Ninja` on Unix-like systems when it is available
- `Unix Makefiles` on Unix-like systems when `ninja` is not installed

This boilerplate currently supports macOS and Linux.

## Configure, build, and test

### Quick start

```console
git clone https://github.com/megabyde/cpp-boilerplate.git
cd cpp-boilerplate
make conan-profile
make debug
```

Other local convenience targets:

```console
make release
make asan
make coverage
```

These targets do not define the build. They just run the matching Conan install command and then
delegate to the public CMake presets and workflows.

### AddressSanitizer

```console
make asan
```

This uses a dedicated ASAN build tree under `build/DebugAsan`.

> [!NOTE]
> Conan owns the dependency graph, generator, toolchain, and ABI settings. If you switch the Conan
> configuration, rerun `make bootstrap` or the matching public `make` target and keep using the
> same public CMake preset names.

### Tests

Tests are controlled by CMake's built-in `BUILD_TESTING` option from `include(CTest)`. This
project leaves it at the default `ON`, so the `release`, `asan`, and `coverage` workflows run the
test suite by default.

## Public presets

- Configure presets: `debug`, `release`, `asan`, `coverage`
- Build presets: `debug`, `release`, `asan`, `coverage`
- Test presets: `debug`, `release`, `asan`, `coverage`
- Workflow presets: `debug`, `release`, `asan`, `coverage`

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

Generate an LCOV tracefile and HTML report with:

```console
make coverage
```

This writes:

- `build/DebugCoverage/coverage.info`
- `build/DebugCoverage/coverage-report/index.html`

## Editor setup

### VS Code

VS Code with CMake Tools will discover the checked-in public presets automatically after Conan
generates `ConanPresets.json`. Run `make bootstrap` first to generate both debug and release Conan
toolchains and presets.

Then open the folder, accept the recommended extensions, and select the matching public preset.
For the checked-in launch configuration, choose the target you want in the CMake Tools sidebar and
start the platform-specific `Debug: CMake Target (...)` configuration. F5 will run the public
`debug` workflow first and then launch the selected executable from `build/Debug`. On macOS, the
repository uses the CodeLLDB extension because the system `lldb` does not support the MI protocol
used by `cppdbg`.

### CLion

CLion can use the same public presets. Run `make bootstrap` first, then in CLion:

1. Open the project root
2. Select the `debug`, `release`, `asan`, or `coverage` preset as the active CMake profile
3. Reload CMake

> [!NOTE]
> No IDE-specific task files are required for the build. The presets are the source of truth.
> `debug`, `asan`, and `coverage` each use their own build tree, so switching between them does not
> require forcing a fresh reconfigure.

## Layout

- `include/`: public headers
- `src/`: application sources
- `tests/`: unit tests
- `conanfile.py`: Conan dependency definition
- `CMakePresets.json`: project-owned public presets and workflows
