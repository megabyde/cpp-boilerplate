# C++ Boilerplate

[![Build](https://github.com/megabyde/cpp-boilerplate/actions/workflows/build.yml/badge.svg)](https://github.com/megabyde/cpp-boilerplate/actions/workflows/build.yml)
[![C++23](https://img.shields.io/badge/C%2B%2B-23-blue.svg)](https://en.cppreference.com/w/cpp/23)
[![CMake](https://img.shields.io/badge/CMake-3.28%2B-064F8C.svg)](https://cmake.org)
[![Conan](https://img.shields.io/badge/Conan-2.x-6699CB.svg)](https://conan.io)
[![License](https://img.shields.io/badge/license-Unlicense-green.svg)](LICENSE)

## Overview

A modern C++23 project boilerplate using:

- [CMake](https://cmake.org) with checked-in `debug` and `release` presets
- [Conan 2](https://conan.io) for dependency management
- [Boost](https://www.boost.org) via Conan for portable utility libraries
- [GoogleTest](https://github.com/google/googletest) via Conan

## Prerequisites

- CMake 3.28+
- Conan 2
- Ninja
- A compiler and standard library with working C++23 support
  - GCC 13+
  - LLVM Clang 17+
  - Apple Clang 17+ recommended

> [!IMPORTANT]
> If you are on a very new Apple Clang release, make sure your Conan installation and settings are
> up to date before running `conan profile detect`.

> [!NOTE]
> The checked-in `debug` and `release` presets expect Conan toolchain files under `build/debug`
> and `build/release`. The Makefile bootstrap targets create those files for you.

## Configure, build, and test

### Quick start

```console
git clone https://github.com/megabyde/cpp-boilerplate.git
cd cpp-boilerplate
make debug
```

The repo-managed workflow assumes the `Ninja` generator.

### Release build

```console
make release
```

`make debug`, `make release`, and `make coverage` are the normal entry points. The lower-level
`conan-%` and `configure-%` targets are only useful when you explicitly want to stop after
dependency resolution or CMake configure, for example before using an IDE.

To bootstrap the checked-in presets without building yet:

```console
make configure-debug
cmake --build --preset debug
ctest --preset debug
```

### Helper targets

To see all helper targets:

```console
make help
```

Useful maintenance targets:

```console
make clean
make lock
```

> [!NOTE]
> Configuring with `cmake --preset ...` or the Makefile configure/build targets refreshes the root
> `compile_commands.json` symlink to point at the active build directory.

The sample app also demonstrates a small Boost-powered helper that trims and joins
record fields before printing a summary line.

## Dependency lock file

`conan.lock` pins the exact dependency graph for reproducible builds. To update dependencies:

1. Edit version pins in `conanfile.py`.
2. Run `make lock` to regenerate the lock file.
3. Run `make debug` to verify.
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

- `build/debug/coverage.info`
- `build/debug/coverage-report/index.html`

> [!NOTE]
> Coverage reuses the `build/debug` directory configured by the Makefile's `debug` flow.
> `make coverage` reruns the debug test suite and then captures coverage from that build.

> [!NOTE]
> `make coverage` requires `lcov` and `genhtml` to be installed. On Ubuntu, the package is
> `lcov`. On macOS with Homebrew, use `brew install lcov`.

## Editor setup

### VS Code

The repository includes a complete `.vscode/` configuration:

- **settings.json**: enables CMake preset mode and points IntelliSense at the root
  `compile_commands.json` symlink.
- **launch.json**: a cross-platform debug configuration that launches whichever CMake target is
  selected in the CMake Tools sidebar.
- **tasks.json**: optional `Setup: Debug` and `Setup: Release` tasks that run the Makefile
  bootstrap flow.
- **extensions.json**: recommends the C/C++ and CMake Tools extensions.

Before the first IDE configure, bootstrap the toolchain files once:

```console
make configure-debug
```

Then open the folder in VS Code, accept the recommended extensions, and select the `debug` or
`release` preset.

### CLion

Before the first configure in CLion, generate the Conan toolchain files once with:

```console
make configure-debug
```

Then in CLion:

1. Open the project root
2. Select the `debug` or `release` preset as the active CMake profile
3. Reload CMake

> [!NOTE]
> This repo does not rely on the Conan CLion plugin. The Makefile bootstrap plus checked-in CMake
> presets are the source of truth.

## Layout

- `include/`: public headers
- `src/`: application sources
- `tests/`: unit tests
- `conanfile.py`: Conan dependency definition
- `Makefile`: helper targets for local development and CI
