# C++ Boilerplate

[![Build](https://github.com/megabyde/cpp-boilerplate/actions/workflows/build.yml/badge.svg)](https://github.com/megabyde/cpp-boilerplate/actions/workflows/build.yml)
[![Pages](https://github.com/megabyde/cpp-boilerplate/actions/workflows/pages.yml/badge.svg)](https://github.com/megabyde/cpp-boilerplate/actions/workflows/pages.yml)
[![C++23](https://img.shields.io/badge/C%2B%2B-23-blue.svg)](https://en.cppreference.com/w/cpp/23)
[![CMake](https://img.shields.io/badge/CMake-3.25%2B-064F8C.svg)](https://cmake.org)
[![Conan](https://img.shields.io/badge/Conan-2.x-6699CB.svg)](https://conan.io)
[![License](https://img.shields.io/badge/license-Unlicense-green.svg)](./LICENSE)

## Overview

A C++23 project template demonstrating end-to-end toolchain integration: Conan 2.25+
dependency management, CMake presets, testing, sanitizers, coverage, CI, and IDE setup.

This repository uses:

- [CMake](https://cmake.org) configure, build, and test presets as the public build interface
- [Conan 2](https://conan.io) for dependency management
- [spdlog](https://github.com/gabime/spdlog) via Conan as the sample compiled dependency
- [CLI11](https://github.com/CLIUtils/CLI11) via Conan for command-line parsing
- [GoogleTest](https://github.com/google/googletest) via Conan
- [Doxygen](https://www.doxygen.nl) for generated API documentation

## Instantiate this template

After creating your own repository from this
[template](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-repository-from-a-template),
rename the project's identifiers with [`scripts/rename.py`](scripts/rename.py) (stdlib only, no
dependencies):

```console
python3 scripts/rename.py my-project --github-owner your-github-user
```

From `my-project` this derives `my_project` (the CMake project/target names, the C++ namespace,
and the include directory) and `MyProjectConan` (the Conan recipe class), then rewrites every
occurrence across `CMakeLists.txt`, `conanfile.py`, `cmake/version.hpp.in`, `include/`, `src/`,
`tests/`, `README.md`, and the CI workflows. Run with `--dry-run` first to preview every change
without writing anything; add `--title "My Project"` to control the README heading text
(default: Title Case of the name). The real run also moves `include/cpp_boilerplate/` to
`include/my_project/` and removes itself and this section, since neither is needed once the
project has its final name.

## Operating model

The build is layered, and each layer owns one thing:

- **Conan** owns the dependency graph, the toolchain, the CMake generator, and the ABI-relevant
  settings. It resolves them from [`conanfile.py`](conanfile.py) and the [`profiles/`](profiles)
  files; [`conan.lock`](conan.lock) pins the exact graph for reproducible builds.
- **CMake presets** ([`CMakePresets.json`](CMakePresets.json)) are the public build interface:
  the `debug`, `release`, `sanitize*`, and `coverage` names you configure, build, and test. They
  are checked in and are the source of truth for how the project is built.
- Conan writes its toolchain details into a generated `ConanPresets.json` that
  `CMakePresets.json` includes. That file is an implementation detail, not an interface;
  `make bootstrap` is the one-time per-clone step that materializes it.
- The [`Makefile`](Makefile) is a thin convenience wrapper: each target runs `conan install` for
  the right profile, then `cmake --workflow --preset <name>`. On Windows you run those two
  commands directly (see [Windows](#windows)).

When you change the Conan configuration (versions, options, or profile), rerun `make bootstrap` or
the matching `make` target and keep using the same public preset names. The preset interface is
stable across toolchain changes.

## Layout

```text
.
|-- include/                 public headers
|-- src/                     application sources
|-- tests/                   unit tests
|-- conanfile.py             Conan dependency definition
|-- conan/settings_user.yml  custom sanitizer setting
|-- profiles/                default and sanitizer Conan profiles
`-- CMakePresets.json        project-owned public presets
```

## Prerequisites

- [CMake](https://cmake.org/download/) 3.25+ (for workflow presets)
- [Conan](https://docs.conan.io/2/installation.html) 2.25+ (for the `CMakeConfigDeps` generator)
- [Ninja](https://ninja-build.org/) (optional, Unix only; GNU Make is used when absent)
- [ccache](https://ccache.dev/) (optional; used automatically for first-party targets when on
  PATH; not with the Visual Studio generator, which ignores compiler launchers)
- [Doxygen](https://www.doxygen.nl) (optional; required only for `make docs`)
- A compiler and standard library with working C++23 support
  - [GCC](https://gcc.gnu.org/) 13+
  - [LLVM Clang](https://llvm.org/) 17+
  - [Apple Clang](https://developer.apple.com/xcode/) 17+ recommended
  - [MSVC](https://visualstudio.microsoft.com/) 2022 (17.10+) on Windows

Conan chooses the CMake generator for you:

- `Ninja` on Unix-like systems when it is available
- `Unix Makefiles` on Unix-like systems when `ninja` is not installed
- The Visual Studio generator matching the detected MSVC on Windows (multi-config; locates
  MSVC itself, so no extra tool or `vcvars` environment is needed)

This boilerplate supports Linux, macOS, and Windows.

## Configure, build, and test

### Quick start

```console
git clone https://github.com/megabyde/cpp-boilerplate.git
cd cpp-boilerplate
make bootstrap  # generates ConanPresets.json
make debug
```

> [!TIP]
> Run `make help` to list local convenience targets.

### Windows

The `Makefile` is a Unix convenience wrapper. On Windows, drive Conan and the CMake
presets directly from any shell; the Visual Studio generator locates MSVC on its own,
so no Developer PowerShell or `vcvarsall` setup is required:

```console
conan install . -pr=profiles/default -s="build_type=Release" --build=missing --lockfile=conan.lock
cmake --workflow --preset release
```

`cmake --workflow --preset <name>` runs configure, build, and test in one step; it
is what the `make` targets call on Unix too. The `sanitize`, `sanitize-asan`,
`sanitize-ubsan`, and `coverage` presets are Unix-only.

### Sanitizers (ASAN + UBSAN)

```console
make sanitize
make sanitize-asan
make sanitize-ubsan
```

This uses a dedicated sanitizer build tree (Conan names it `build/debug-addressundefinedbehavior`
after the build type and `compiler.sanitizer` setting) and a Conan sanitize profile so
dependencies are rebuilt with matching instrumentation, not linked from their plain
(uninstrumented) Debug binaries.

Three modes are provided, showcasing Conan profile inheritance. Each mode profile inherits a
shared base, [`profiles/sanitize-common`](profiles/sanitize-common) (which pulls in
`profiles/default`, sets `Debug`, and carries the common instrumentation flags and `[runenv]`),
and appends its own `-fsanitize` flags:

- `sanitize`: combined ASan + UBSan ([`profiles/sanitize`](profiles/sanitize)); driven by
  `make sanitize` and CI.
- `sanitize-asan`: AddressSanitizer only ([`profiles/sanitize-asan`](profiles/sanitize-asan)).
- `sanitize-ubsan`: UndefinedBehaviorSanitizer only
  ([`profiles/sanitize-ubsan`](profiles/sanitize-ubsan)).

Each `make sanitize*` target installs the matching instrumented dependency graph, then runs the
matching CMake workflow preset. All three modes share `conan.lock`.

Each mode gets its own `package_id` and build tree (`build/debug-address`,
`build/debug-undefinedbehavior`, `build/debug-addressundefinedbehavior`).

ASan/UBSan runtime options (`halt_on_error`, `print_stacktrace`, and related checks) live in
`profiles/sanitize-common` under `[runenv]` (inherited by every mode). Conan injects them into
the generated per-mode test preset, which the public `sanitize*` test preset inherits, so
`ctest`/`cmake --workflow` runs the instrumented tests with those options: a single source of
truth, no duplication in `CMakePresets.json`.

That separation relies on a custom `compiler.sanitizer` setting defined in
[`conan/settings_user.yml`](conan/settings_user.yml). The setting gives instrumented
dependency binaries a distinct Conan `package_id`; the sanitizer flags themselves
travel through the profile's `tools.build:*` conf, which does not affect `package_id`.
Without the setting, `--build=missing` would silently reuse the uninstrumented Debug
binaries.

`make bootstrap-sanitize` installs that file into your Conan home with
`conan config install conan/` (the repository's `conan/` directory) before resolving
dependencies, but only when the home has no `settings_user.yml` yet. An existing file
(for example one your dotfiles manage) is left untouched; it just has to cover the
sanitizer values this project uses. A superset (extra compilers, values, or other
subsettings) is fine: [`scripts/check_settings_subset.py`](scripts/check_settings_subset.py)
verifies this and the build stops with a merge instruction when values are missing.
This is a global Conan
side effect: it adds the `compiler.sanitizer` subsetting (default `null`, omitted from
`package_id`) and does not change non-sanitize builds.

The default `make bootstrap` does not install sanitizer-instrumented dependencies. Run
`make bootstrap-sanitize` or the matching `make sanitize*` target when you need them.

First-party targets are instrumented by the same Conan toolchain (the profile's
`tools.build:*` flags reach the consumer), so the profiles are the single source of
sanitizer flags.

### Tests

Tests are controlled by CMake's built-in `BUILD_TESTING` option from `include(CTest)`. This
project leaves it at the default `ON`, so `make debug`, `make release`, `make sanitize*`, and
`make coverage` all run the GTest suite.

## Public presets

The main workflow presets are `debug`, `release`, `sanitize`, `sanitize-asan`, `sanitize-ubsan`,
and `coverage`. Configure, build, and test presets use the same names. `docs` is configure/build
only because it generates Doxygen HTML instead of compiling and testing the application.

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

`make format` and `make format-check` cover C++ sources (clang-format) and `CMakeLists.txt`
(cmake-format, from the [cmakelang](https://cmake-format.readthedocs.io) package). `make lint`
runs clang-tidy against the debug compilation database; every enabled check is an error.

## Coverage

Build, test, and generate an HTML coverage report with an enforced line floor:

```console
make coverage-report
```

Both compilers emit GCov-format data (`--coverage`), reported by a single tool:
[gcovr](https://gcovr.com) (`pip install gcovr`). It writes
`coverage-report/index.html` and `coverage.xml` under `build/coverage/`.

The report fails if line coverage falls below `COVERAGE_FAIL_UNDER` (default 100;
override with `make coverage-report COVERAGE_FAIL_UNDER=80`).

## Documentation

Generate Doxygen HTML documentation locally:

```console
make docs
```

The output is written to `build/docs/html/`. GitHub Pages builds the same target and publishes the
result from the `main` branch.

## Build policy

Warnings are errors by default (`WARNINGS_AS_ERRORS`, default `ON`) in every preset, locally and
in CI. Relax it for a single build tree with `cmake --preset <name> -DWARNINGS_AS_ERRORS=OFF`.

First-party targets also build with hardening flags by default (`ENABLE_HARDENING`, default `ON`;
disable with `-DENABLE_HARDENING=OFF` on any configure preset):

- GCC/Clang/AppleClang: `-fstack-protector-strong` and architecture-matched control-flow
  protection (`-fcf-protection=full` on x86-64; `-mbranch-protection=standard` on AArch64,
  Linux only, because pac-ret frames break exception unwinding under macOS's compact-unwind
  format) in every configuration; optimized configurations add
  `-U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=2` (Debug skips fortification because it requires
  optimization). Executables link as PIE so ASLR covers the program image, and on Linux the
  linker adds full RELRO (`-z relro -z now`) and an explicitly non-executable stack.
- MSVC: `/guard:cf` (Control Flow Guard) at compile and link; x64 also links with
  `/CETCOMPAT` (CET shadow stack).
- Other compilers build unhardened rather than failing to configure.

First-party targets build the `release` preset with link-time optimization (LTO) by default
(`ENABLE_LTO`, default `ON`; disable with `-DENABLE_LTO=OFF`). It applies only to the `Release`
configuration (CMake's `INTERPROCEDURAL_OPTIMIZATION_RELEASE` property), so `debug`, `sanitize*`,
and `coverage` builds are unaffected; when the toolchain reports no LTO support, configure logs
the reason and continues without it rather than failing.

Sanitizer and coverage builds omit fortification (they build as Debug, which never defines
`_FORTIFY_SOURCE`): fortify conflicts with the ASan interceptors, and coverage builds run at
`-O0` where glibc fortification warns. The other hardening flags stay on. Like the
warning options, hardening covers first-party code only; dependency binaries from the Conan
cache are not rebuilt with these flags.

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
$ /path/to/prefix/bin/cpp_boilerplate --version
0.1.0
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
2. Select the `debug`, `release`, `sanitize*`, or `coverage` preset as the active CMake profile
3. Reload CMake

> [!NOTE]
> No IDE-specific task files are required for the build. The presets are the source of truth.
> `debug`, `sanitize`, and `coverage` each use their own build tree, so switching between them
> does not require forcing a fresh reconfigure.
