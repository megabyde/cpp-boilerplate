# C++ Boilerplate

[![Build](https://github.com/megabyde/cpp-boilerplate/actions/workflows/build.yml/badge.svg)](https://github.com/megabyde/cpp-boilerplate/actions/workflows/build.yml)
[![CodeQL](https://github.com/megabyde/cpp-boilerplate/actions/workflows/codeql.yml/badge.svg)](https://github.com/megabyde/cpp-boilerplate/actions/workflows/codeql.yml)
[![Pages](https://github.com/megabyde/cpp-boilerplate/actions/workflows/pages.yml/badge.svg)](https://github.com/megabyde/cpp-boilerplate/actions/workflows/pages.yml)
[![C++23](https://img.shields.io/badge/C%2B%2B-23-blue.svg)](https://en.cppreference.com/w/cpp/23)
[![CMake](https://img.shields.io/badge/CMake-3.29%2B-064F8C.svg)](https://cmake.org)
[![Conan](https://img.shields.io/badge/Conan-2.x-6699CB.svg)](https://conan.io)
[![License](https://img.shields.io/badge/license-Unlicense-green.svg)](./LICENSE)

## Overview

A C++23 project template with Conan 2.25+ dependency management, CMake presets, testing, sanitizers,
coverage, CI, and IDE setup.

This repository uses:

- [CMake](https://cmake.org) configure, build, and test presets as the public build interface
- [Conan 2](https://conan.io) for dependency management
- [spdlog](https://github.com/gabime/spdlog) via Conan as the sample compiled dependency
- [CLI11](https://github.com/CLIUtils/CLI11) via Conan for command-line parsing
- [GoogleTest](https://github.com/google/googletest) via Conan
- [Doxygen](https://www.doxygen.nl) for generated API documentation

## Instantiate this template

Outcome: a new repository with project names, targets, namespaces, include paths, and GitHub links
renamed consistently.

First, create and clone a repository from this
[template](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-repository-from-a-template).
The rename script uses only the Python standard library.

1. Preview every change without modifying the checkout:

   ```console
   $ python3 scripts/rename.py my-project --github-owner your-github-user --dry-run
   ...

   Dry run: no files were changed. Re-run without --dry-run to apply.
   ```

   The command must end with `Dry run: no files were changed.` Review the listed rewrites, move, and
   removals before continuing.

2. Apply the same rename without `--dry-run`:

   ```console
   $ python3 scripts/rename.py my-project --github-owner your-github-user
   ...
   Moved include/cpp_boilerplate -> include/my_project
   Removing scripts/rename.py
   Removing .github/workflows/template.yml
   ```

From `my-project`, the script derives `my_project` for CMake targets, the C++ namespace, and the
include directory. It derives `MyProjectConan` for the Conan recipe class. It then updates the
tracked project files and moves `include/cpp_boilerplate/` to `include/my_project/`. Finally it
removes the three things that stop applying once the template is instantiated: itself, this section,
and `.github/workflows/template.yml`, the workflow that smoke-tests the rename.

The rename is complete when the command reports the rewritten files, moves
`include/cpp_boilerplate/` to `include/my_project/`, and removes the script and template workflow.
Use `--title "My Project"` to override the README heading; the default is the project name in title
case.

## Operating model

The build is layered, and each layer owns one thing:

- **Conan** owns the dependency graph, the toolchain, the CMake generator, and the ABI-relevant
  settings. It resolves them from [`conanfile.py`](conanfile.py) and the [`profiles/`](profiles)
  files; [`conan.lock`](conan.lock) pins the exact graph for reproducible builds.
- **CMake presets** ([`CMakePresets.json`](CMakePresets.json)) are the public build interface: the
  `debug`, `release`, `sanitize*`, and `coverage` names you configure, build, and test. They are
  checked in and are the source of truth for how the project is built.
- Conan writes its toolchain details into a generated `ConanPresets.json` that `CMakePresets.json`
  includes. That file is an implementation detail, not an interface; `make bootstrap` is the
  one-time per-clone step that materializes it.
- The [`Makefile`](Makefile) is a thin convenience wrapper: each target runs `conan install` for the
  right profile, then `cmake --workflow --preset <name>`. On Windows you run those two commands
  directly (see [Windows](#windows)).

When you change the Conan configuration (versions, options, or profile), rerun `make bootstrap` or
the matching `make` target and keep using the same public preset names. The preset interface is
stable across toolchain changes.

## Layout

```text
.
├── include/                 public headers
├── src/                     application sources
├── tests/                   unit tests
├── conanfile.py             Conan dependency definition
├── conan/settings_user.yml  custom sanitizer setting
├── profiles/                default and sanitizer Conan profiles
└── CMakePresets.json        project-owned public presets
```

## Prerequisites

Required:

- [CMake](https://cmake.org/download/) 3.29+ (for workflow presets and `CMAKE_LINKER_TYPE`)
- [Conan](https://docs.conan.io/2/installation.html) 2.25+ (for the `CMakeConfigDeps` generator)
- A compiler and standard library with C++23 `std::ranges::to` support
  - [GCC](https://gcc.gnu.org/) 14+
  - [LLVM Clang](https://llvm.org/) 17+ with libc++ 17+ or libstdc++ 14+
  - [Apple Clang](https://developer.apple.com/xcode/) 17+ on macOS
  - [MSVC](https://visualstudio.microsoft.com/) 2022 (17.10+) on Windows

Optional:

- [Ninja](https://ninja-build.org/) for parallel, incremental Unix builds; GNU Make is used when
  Ninja is absent
- [ccache](https://ccache.dev/) to reuse compiler output across rebuilds; used automatically for
  first-party targets when on PATH, except with the Visual Studio generator, which ignores compiler
  launchers
- [mold](https://github.com/rui314/mold) or [LLD](https://lld.llvm.org/) to reduce Linux link times;
  used automatically for first-party targets when on PATH, with mold preferred
- [Doxygen](https://www.doxygen.nl) to generate local API documentation with `make docs`

The Conan recipe selects the CMake generator:

- `Ninja` on Unix-like systems when it is available
- `Unix Makefiles` on Unix-like systems when `ninja` is not installed
- The Visual Studio generator matching the detected MSVC on Windows (multi-config; locates MSVC
  itself, so no extra tool or `vcvars` environment is needed)

This boilerplate supports Linux, macOS, and Windows.

## Configure, build, and test

### Quick start

Outcome: dependencies installed, the debug preset configured and built, and the test suite passed.

```bash
git clone https://github.com/megabyde/cpp-boilerplate.git
cd cpp-boilerplate
make bootstrap  # generate ConanPresets.json
make debug
```

The setup is complete when `make debug` exits successfully after running the tests.

> [!TIP]
> Run `make help` to list the other local targets.

### Windows

Outcome: dependencies installed, the release preset configured and built, and the test suite passed.

The `Makefile` is a Unix convenience wrapper. On Windows, run Conan and the CMake preset directly
from any shell. The Visual Studio generator locates MSVC, so no Developer PowerShell or `vcvarsall`
setup is required.

```bash
conan install . -pr=profiles/default -s="build_type=Release" --build=missing --lockfile=conan.lock
cmake --workflow --preset release
```

The setup is complete when the workflow exits successfully after running the tests.
`cmake --workflow --preset <name>` runs configure, build, and test in one step; the Unix `make`
targets call the same workflows. The `sanitize`, `sanitize-asan`, `sanitize-ubsan`, and `coverage`
presets are Unix-only.

## Development workflows

For sanitizer modes, test and preset behavior, dependency updates, formatting and linting,
coverage, documentation generation, build policy, and IDE setup, see
[Development workflows](docs/development.md).

## Install

Outcome: the release application installed at `<prefix>/bin/cpp_boilerplate`. Only the executable is
installed; the static library remains an internal build artifact.

1. Build and test the release preset:

```bash
cmake --workflow --preset release
```

1. Install to the selected prefix:

```bash
cmake --install build/release --prefix /path/to/prefix
```

1. Run the installed binary and verify its version:

```console
$ /path/to/prefix/bin/cpp_boilerplate
[2026-06-30 20:46:16.431] [info] cpp-boilerplate 0.1.0 starting
[2026-06-30 20:46:16.431] [info] field 0: alpha
[2026-06-30 20:46:16.431] [info] field 1: beta
[2026-06-30 20:46:16.431] [info] field 2: gamma
[2026-06-30 20:46:16.431] [info] done
$ /path/to/prefix/bin/cpp_boilerplate --version
0.1.0
```

The install is complete when both installed-binary commands succeed and `--version` prints the
expected project version.
