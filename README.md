# C++ Boilerplate

[![Build](https://github.com/megabyde/cpp-boilerplate/actions/workflows/build.yml/badge.svg)](https://github.com/megabyde/cpp-boilerplate/actions/workflows/build.yml)

## Overview

A modern C++23 project boilerplate using:

- [CMake](https://cmake.org) with checked-in presets
- [Conan 2](https://conan.io) for dependency management
- [Boost](https://www.boost.org) via Conan for portable utility libraries
- [GoogleTest](https://github.com/google/googletest) via Conan

## Prerequisites

- CMake 3.28+
- Conan 2
- A C++23-capable compiler
- Ninja or another CMake-supported generator

If you are on a very new Apple Clang release, make sure your Conan installation and settings are up
to date before running `conan profile detect`.

## Configure, build, and test

```console
git clone https://github.com/megabyde/cpp-boilerplate.git
cd cpp-boilerplate
make conan-profile
make debug
```

For a release build:

```console
make release
```

To see the available helper targets:

```console
make help
```

Formatting and linting helpers:

```console
make format
make format-check
make lint
```

`make configure-debug` and `make configure-release` also refresh the root
`compile_commands.json` symlink to point at the active build directory.

The sample app also demonstrates a small Boost-powered helper that trims and joins
record fields before printing a summary line.

## Layout

- `include/`: public headers
- `src/`: application sources
- `tests/`: unit tests
- `conanfile.py`: Conan dependency definition
- `CMakePresets.json`: standard configure/build/test entry points
- `Makefile`: helper targets for local development and CI
