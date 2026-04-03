# C++ Boilerplate

[![Build](https://github.com/megabyde/cpp-boilerplate/actions/workflows/build.yml/badge.svg)](https://github.com/megabyde/cpp-boilerplate/actions/workflows/build.yml)
[![C++23](https://img.shields.io/badge/C%2B%2B-23-blue.svg)](https://en.cppreference.com/w/cpp/23)
[![CMake](https://img.shields.io/badge/CMake-3.28%2B-064F8C.svg)](https://cmake.org)
[![Conan](https://img.shields.io/badge/Conan-2.x-6699CB.svg)](https://conan.io)
[![License](https://img.shields.io/badge/license-Unlicense-green.svg)](LICENSE)

## Overview

A modern C++23 project boilerplate using:

- [CMake](https://cmake.org) presets and workflow presets as the public build interface
- [Conan 2](https://conan.io) for dependency management
- [Boost](https://www.boost.org) via Conan for portable utility libraries
- [GoogleTest](https://github.com/google/googletest) via Conan

The project keeps the public presets in the repository and lets Conan generate the toolchain and
its internal presets:

- the project owns [`CMakePresets.json`](CMakePresets.json)
- Conan generates `ConanPresets.json`
- the public presets (`debug`, `release`, `asan`, `coverage`, `ci`) inherit from Conan's internal
  presets

The checked-in presets are the source of truth. The [`Makefile`](Makefile) is only a thin
convenience wrapper around `conan install` plus the public CMake presets and workflows.

## Prerequisites

- CMake 3.28+
- Conan 2
- Ninja or GNU Make on Unix-like systems
- Visual Studio 2022 on Windows
- A compiler and standard library with working C++23 support
  - GCC 13+
  - LLVM Clang 17+
  - Apple Clang 17+ recommended
  - MSVC 19.3x or newer on Windows

> [!IMPORTANT]
> If you are on a very new Apple Clang release, make sure your Conan installation and settings are
> up to date before running `conan profile detect`.

Conan chooses the CMake generator for you:

- `Ninja` on Unix-like systems when it is available
- `Unix Makefiles` on Unix-like systems when `ninja` is not installed
- `Visual Studio 17 2022` on Windows

## Configure, build, and test

### Development workflow

```console
git clone https://github.com/megabyde/cpp-boilerplate.git
cd cpp-boilerplate
conan profile detect --force
conan install . -s compiler.cppstd=23 -s build_type=Debug --lockfile=conan.lock --build=missing
cmake --workflow --preset debug
```

### CI workflow

```console
conan install . -s compiler.cppstd=23 -s build_type=Release --lockfile=conan.lock --build=missing
cmake --workflow --preset ci
```

### Makefile convenience

```console
make debug
make bootstrap
make release
make asan
make ci
```

These targets do not define the build. They just run the matching Conan install command and then
delegate to the public presets and workflows.

### Direct preset usage

```console
conan install . -s compiler.cppstd=23 -s build_type=Debug --lockfile=conan.lock --build=missing
cmake --preset debug
cmake --build --preset debug
ctest --preset debug
```

```console
conan install . -s compiler.cppstd=23 -s build_type=Release --lockfile=conan.lock --build=missing
cmake --preset release
cmake --build --preset release
ctest --preset release
```

### AddressSanitizer

```console
conan install . -s compiler.cppstd=23 -s build_type=Debug -o '&:asan=True' --lockfile=conan.lock --build=missing
cmake --preset asan
cmake --build --preset asan
ctest --preset asan
```

> [!NOTE]
> Conan owns the dependency graph, generator, toolchain, and ABI settings. If you switch the Conan
> configuration, rerun `conan install` for that configuration and keep using the same public CMake
> preset names.

## Public presets

- Configure presets: `debug`, `release`, `asan`, `coverage`, `ci`
- Build presets: `debug`, `release`, `asan`, `coverage`, `ci`
- Test presets: `debug`, `release`, `asan`, `coverage`, `ci`
- Workflow presets: `debug`, `ci`

The Conan-generated `conan-*` presets are internal implementation details and are not the public
interface for developers or CI.

## Dependency lock file

`conan.lock` pins the exact dependency graph for reproducible builds. To update dependencies:

1. Edit version pins in `conanfile.py`.
2. Regenerate the lock file with `conan lock create`.
3. Run the appropriate `conan install` and `cmake --workflow` commands to verify.
4. Commit both `conanfile.py` and `conan.lock`.

## Formatting and linting

```console
clang-format -i $(find include src tests -type f \( -name '*.hpp' -o -name '*.cpp' \))
clang-format --dry-run --Werror $(find include src tests -type f \( -name '*.hpp' -o -name '*.cpp' \))
clang-tidy -p build/debug src/main.cpp tests/split_test.cpp
```

## Coverage

Generate an LCOV tracefile and HTML report with:

```console
conan install . -s compiler.cppstd=23 -s build_type=Debug --lockfile=conan.lock --build=missing
cmake --preset coverage --fresh
cmake --build --preset coverage
ctest --preset coverage
lcov --capture --directory build/debug --base-directory . --no-external --output-file build/debug/coverage.info
genhtml build/debug/coverage.info --output-directory build/debug/coverage-report
```

Or use the convenience wrapper:

```console
make coverage
```

This writes:

- `build/debug/coverage.info`
- `build/debug/coverage-report/index.html`

## Editor setup

### VS Code

VS Code with CMake Tools will discover the checked-in public presets automatically after Conan
generates `ConanPresets.json`. Bootstrap the matching Conan configuration first:

```console
conan install . -s compiler.cppstd=23 -s build_type=Debug --lockfile=conan.lock --build=missing
```

Use:

- `build_type=Debug` for `debug` and `coverage`
- `build_type=Release` for `release` and `ci`
- `build_type=Debug -o '&:asan=True'` for `asan`

Or run `make bootstrap` to generate both the debug and release Conan presets up front.

Then open the folder, accept the recommended extensions, and select the matching public preset.

### CLion

CLion can use the same public presets. Generate `ConanPresets.json` first:

```console
conan install . -s compiler.cppstd=23 -s build_type=Debug --lockfile=conan.lock --build=missing
```

Use the same matching Conan configuration rules as VS Code, or run `make bootstrap` first. Then in
CLion:

1. Open the project root
2. Select the `debug`, `release`, `asan`, or `ci` preset as the active CMake profile
3. Reload CMake

> [!NOTE]
> No IDE-specific task files are required for the build. The presets are the source of truth.
> If you switch between `debug`, `asan`, and `coverage`, rerun the configure step with `--fresh` so
> CMake rebuilds the shared debug cache from the matching Conan-generated preset.

## Layout

- `include/`: public headers
- `src/`: application sources
- `tests/`: unit tests
- `conanfile.py`: Conan dependency definition
- `CMakePresets.json`: project-owned public presets and workflows
