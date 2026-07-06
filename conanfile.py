import os
import re
import shutil

from conan import ConanFile
from conan.tools.build import check_min_cppstd
from conan.tools.cmake import CMakeConfigDeps, CMakeToolchain, cmake_layout
from conan.tools.files import load


class CppBoilerplateConan(ConanFile):
    required_conan_version = ">=2.25"  # CMakeConfigDeps is available from 2.25
    name = "cpp-boilerplate"
    package_type = "application"

    settings = "os", "compiler", "build_type", "arch"

    options = {"with_tests": [True, False]}

    default_options = {
        "with_tests": True,
        "spdlog/*:header_only": False,
        "spdlog/*:shared": False,
        "spdlog/*:use_std_fmt": False,  # use bundled fmt to exercise the dep graph
    }

    def set_version(self):
        # Single source of truth: parse the version from the CMake project() call so the
        # Conan and CMake versions cannot drift. CMakeLists.txt owns it.
        cmakelists = load(self, os.path.join(self.recipe_folder, "CMakeLists.txt"))
        self.version = re.search(r"project\([^)]*VERSION\s+([\d.]+)", cmakelists).group(1)

    def requirements(self):
        # The method form (over the `requires` attribute) is what lets requirements be
        # conditional, e.g. platform-specific extras:
        #   if self.settings.os == "Windows":
        #       self.requires("...")
        self.requires("spdlog/1.17.0")

    def validate(self):
        # Require C++23 at the standard level (catches a profile pinning an older
        # compiler.cppstd). An actually-too-old compiler is rejected by CMake's
        # cxx_std_23 feature requirement at configure time, so we deliberately do not
        # duplicate a compiler-version table here; the README documents the minimums.
        check_min_cppstd(self, 23)

    def _cmake_generator(self):
        # Windows always uses the Visual Studio generator: it locates MSVC itself (no
        # vcvars environment needed) and needs no extra tool on PATH. Return None so
        # CMakeToolchain deduces the VS release from the detected compiler.version
        # (msvc 194 -> "Visual Studio 17 2022", 195 -> "Visual Studio 18 2026");
        # hardcoding a year breaks when the machine has a different VS installed.
        # The preset names and build folders stay aligned with the single-config
        # generators because build_folder_vars (see layout()) pins both, so the
        # public presets are identical across platforms.
        if self.settings.os == "Windows":
            return None
        return "Ninja" if shutil.which("ninja") else "Unix Makefiles"

    def layout(self):
        # Let Conan own the build layout. build_type gives build/debug and build/release;
        # compiler.sanitizer (see conan/settings_user.yml) splits the instrumented build
        # into build/debug-addressundefinedbehavior with its own
        # conan-debug-addressundefinedbehavior
        # preset. An unset or undefined sanitizer is omitted, so plain Debug builds (and
        # clones without settings_user.yml) are unaffected. Coverage is not a Conan
        # dimension; its CMake preset reuses the debug toolchain.
        self.folders.build_folder_vars = ["settings.build_type", "settings.compiler.sanitizer"]
        cmake_layout(self, generator=self._cmake_generator())

    def build_requirements(self):
        # Declare CMake as an explicit build tool. The range matches the project floor and is
        # satisfied from the system CMake via [platform_tool_requires] in profiles/default (so
        # the lock records cmake/<floor>#platform, not a downloaded package). Our own targets
        # build via `cmake --workflow`; the generator (Ninja or Makefiles) is left to the
        # environment, not pinned here.
        self.tool_requires("cmake/[>=3.25]")
        if self.options.with_tests:
            self.test_requires("gtest/1.17.0")

    def generate(self):
        # CMakeConfigDeps generates CMake CONFIG-mode find_package files under the build
        # dir. It is experimental in Conan 2.x (it prints a warning and its behavior may
        # change); we use it to exercise the modern generator. Switch to the stable
        # CMakeDeps if you need a settled interface.
        deps = CMakeConfigDeps(self)
        deps.generate()

        tc = CMakeToolchain(self, generator=self._cmake_generator())
        tc.user_presets_path = "ConanPresets.json"
        # Flow the Conan option into CMake: with tests disabled, BUILD_TESTING (from
        # include(CTest)) is off and find_package(GTest) is never reached.
        tc.cache_variables["BUILD_TESTING"] = bool(self.options.with_tests)
        tc.generate()
