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

### Sanitizers (ASan + UBSan)

Outcome: first-party code and dependencies built with matching sanitizer instrumentation, followed
by the instrumented test suite.

> [!IMPORTANT]
> The first sanitizer build may add `compiler.sanitizer` from
> [`conan/settings_user.yml`](conan/settings_user.yml) to the global Conan configuration. If the
> Conan home already has `settings_user.yml`, the build leaves it untouched and checks that it
> contains the required values. If the check fails, merge the reported values into the existing
> file, then rerun the same command.

Choose one mode:

- **ASan + UBSan:** `make sanitize` uses [`profiles/sanitize`](profiles/sanitize) and
  `build/debug-addressundefinedbehavior`
- **ASan:** `make sanitize-asan` uses [`profiles/sanitize-asan`](profiles/sanitize-asan) and
  `build/debug-address`
- **UBSan:** `make sanitize-ubsan` uses [`profiles/sanitize-ubsan`](profiles/sanitize-ubsan) and
  `build/debug-undefinedbehavior`

The sanitizer run is complete when the selected target exits successfully after running the tests.
If a sanitizer detects an error, it prints a stack trace, stops at the first finding, and returns a
failure through CTest to the selected `make` target. Fix the reported source error, then rerun the
same target.

`make sanitize` is the combined mode used by CI. To install all three instrumented dependency graphs
without running their workflows, use `make bootstrap-sanitize`. The default `make bootstrap` does
not install them.

All three profiles inherit [`profiles/sanitize-common`](profiles/sanitize-common), which includes
`profiles/default`, selects `Debug`, and defines the shared instrumentation flags and `[runenv]`.
Each mode appends its own `-fsanitize` flags and shares `conan.lock`.

The custom `compiler.sanitizer` setting gives each instrumented dependency graph a distinct Conan
`package_id`. Without it, `--build=missing` could reuse plain Debug dependencies. The setting
defaults to `null`, which is omitted from `package_id`, so non-sanitizer builds do not change.
First-party targets receive the same profile flags through the Conan toolchain.

ASan/UBSan runtime options such as `halt_on_error` and `print_stacktrace` live under `[runenv]` in
`profiles/sanitize-common`. Conan injects them into the generated test presets inherited by the
public `sanitize*` presets, keeping the runtime configuration out of `CMakePresets.json`.

### Tests

Tests are controlled by CMake's built-in `BUILD_TESTING` option from `include(CTest)`. This project
leaves it at the default `ON`, so `make debug`, `make release`, `make sanitize*`, and
`make coverage` all run the GTest suite.

## Public presets

The main workflow presets are `debug`, `release`, `sanitize`, `sanitize-asan`, `sanitize-ubsan`, and
`coverage`. Configure, build, and test presets use the same names. `docs` is configure/build only
because it generates Doxygen HTML instead of compiling and testing the application.

The Conan-generated `conan-*` presets are internal implementation details and are not the public
interface for developers or CI.

## Dependency lock file

Outcome: updated dependency pins and a matching `conan.lock` for reproducible builds.

Update dependencies in this order:

1. Edit version pins in `conanfile.py`.
2. Regenerate the lock file with `make lock`.
3. Run the appropriate `make` target to verify.
4. Commit both `conanfile.py` and `conan.lock`.

The update is complete when the selected build and test workflow passes and both files contain the
intended dependency change.

## Formatting and linting

Use `make format` to rewrite supported files in place:

```bash
make format
```

Then verify formatting and lint findings without modifying files:

```bash
make format-check
make lint
```

The check is complete when both verification targets exit successfully. If `make format-check`
fails, rerun `make format` and inspect its changes before checking again. Reported lint findings
require a source fix.

`make format` and `make format-check` cover C++ sources (clang-format), `CMakeLists.txt`
(cmake-format, from the [cmakelang](https://cmake-format.readthedocs.io) package), `scripts/` and
`conanfile.py` ([ruff](https://docs.astral.sh/ruff/) format), and tracked Markdown/JSON/YAML files
([prettier](https://prettier.io); `conan.lock` is excluded because Conan owns its formatting).
`make lint` runs clang-tidy against the debug compilation database, `cmake-lint` on
`CMakeLists.txt`, `ruff check` on `scripts/` and `conanfile.py`, and
[markdownlint](https://github.com/DavidAnson/markdownlint-cli2) on Markdown files. Any reported
finding fails the target. CI pins all lint and format tool versions in
[`.github/ci.env`](.github/ci.env).

## Coverage

Prerequisite: Python 3.10+ with [gcovr](https://gcovr.com) installed (e.g., `pip install gcovr`).

Build, test, and generate the coverage report:

```bash
make coverage-report
```

The run is complete when the tests pass, gcovr reports a line percentage at or above the configured
floor, and these files exist:

- `build/coverage/coverage-report/index.html`
- `build/coverage/coverage.xml`

Both supported compilers emit GCov-format data (`--coverage`), which gcovr reports through one
interface.

The report fails if line coverage falls below `COVERAGE_FAIL_UNDER` (default 100; override with
`make coverage-report COVERAGE_FAIL_UNDER=80`).

## Documentation

Prerequisite: Doxygen installed and available on `PATH`.

Generate the API documentation:

```bash
make docs
```

The build is complete when `build/docs/html/index.html` exists. GitHub Pages runs the same target
and publishes the result from the `main` branch.

## Build policy

Warnings are errors by default (`WARNINGS_AS_ERRORS`, default `ON`) in every preset, locally and in
CI. Relax it for a single build tree with `cmake --preset <name> -DWARNINGS_AS_ERRORS=OFF`.

First-party targets also build with hardening flags by default (`ENABLE_HARDENING`, default `ON`;
disable with `-DENABLE_HARDENING=OFF` on any configure preset):

- GCC/Clang/AppleClang: `-fstack-protector-strong` and architecture-matched control-flow protection
  (`-fcf-protection=full` on x86-64; `-mbranch-protection=standard` on AArch64, Linux only, because
  pac-ret frames break exception unwinding under macOS's compact-unwind format) in every
  configuration; optimized configurations add `-U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=2` (Debug skips
  fortification because it requires optimization). Executables link as PIE so ASLR covers the
  program image, and on Linux the linker adds full RELRO (`-z relro -z now`) and an explicitly
  non-executable stack.
- MSVC: `/guard:cf` (Control Flow Guard) at compile and link; x64 also links with `/CETCOMPAT` (CET
  shadow stack).
- Other compilers build unhardened rather than failing to configure.

First-party targets build the `release` preset with link-time optimization (LTO) by default
(`ENABLE_LTO`, default `ON`; disable with `-DENABLE_LTO=OFF`). It applies only to the `Release`
configuration (CMake's `INTERPROCEDURAL_OPTIMIZATION_RELEASE` property), so `debug`, `sanitize*`,
and `coverage` builds are unaffected; when the toolchain reports no LTO support, configure logs the
reason and continues without it rather than failing.

Sanitizer and coverage builds omit fortification (they build as Debug, which never defines
`_FORTIFY_SOURCE`): fortify conflicts with the ASan interceptors, and coverage builds run at `-O0`
where glibc fortification warns. The other hardening flags stay on. Like the warning options,
hardening covers first-party code only; dependency binaries from the Conan cache are not rebuilt
with these flags.

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

## IDE setup

### VS Code

Prerequisite: run `make bootstrap` so Conan generates `ConanPresets.json`.

1. Open the project folder in VS Code.
2. Accept the recommended extensions.
3. Select the matching public preset in CMake Tools.
4. Select a target in the CMake Tools sidebar.
5. Start `Debug: CMake Target` or press F5.

Setup is complete when F5 builds the selected debug target and launches it from `build/debug`.

### CLion

Prerequisite: run `make bootstrap` so Conan generates `ConanPresets.json`.

In CLion:

1. Open the project root
2. Select the `debug`, `release`, `sanitize*`, or `coverage` preset as the active CMake profile
3. Reload CMake

Setup is complete when CLion finishes reloading the selected public preset without a configure
error.

> [!NOTE]
> No IDE-specific task files are required for the build. The presets are the source of truth.
> `debug`, `sanitize`, and `coverage` each use their own build tree, so switching between them
> does not require forcing a fresh reconfigure.
