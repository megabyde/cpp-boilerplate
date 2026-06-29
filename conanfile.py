import shutil

from conan import ConanFile
from conan.tools.cmake import CMakeConfigDeps, CMakeToolchain, cmake_layout


class CppBoilerplateConan(ConanFile):
    required_conan_version = ">=2.25"  # CMakeConfigDeps is available from 2.25
    name = "cpp-boilerplate"
    version = "0.1.0"
    package_type = "application"

    settings = "os", "compiler", "build_type", "arch"

    requires = "spdlog/1.15.3"

    default_options = {
        "spdlog/*:header_only": False,
        "spdlog/*:shared": False,
        "spdlog/*:use_std_fmt": False,  # use bundled fmt to exercise the dep graph
    }

    def _cmake_generator(self):
        if shutil.which("ninja"):
            return "Ninja"
        # Unix Makefiles cannot drive MSVC; fall back to the VS generator there.
        if self.settings.os == "Windows":
            return "Visual Studio 17 2022"
        return "Unix Makefiles"

    def layout(self):
        # Let Conan own the build layout. build_type gives build/debug and build/release;
        # compiler.sanitizer (see conan/settings_user.yml) splits the instrumented build
        # into build/debug-addressundefined with its own conan-debug-addressundefined
        # preset. An unset or undefined sanitizer is omitted, so plain Debug builds (and
        # clones without settings_user.yml) are unaffected. Coverage is not a Conan
        # dimension; its CMake preset reuses the debug toolchain.
        self.folders.build_folder_vars = ["settings.build_type", "settings.compiler.sanitizer"]
        cmake_layout(self, generator=self._cmake_generator())

    def build_requirements(self):
        self.test_requires("gtest/1.15.0")

    def generate(self):
        # CMakeConfigDeps generates CMake CONFIG-mode find_package files under the build
        # dir. It is experimental in Conan 2.x (it prints a warning and its behavior may
        # change); we use it to exercise the modern generator. Switch to the stable
        # CMakeDeps if you need a settled interface.
        deps = CMakeConfigDeps(self)
        deps.generate()

        tc = CMakeToolchain(self, generator=self._cmake_generator())
        tc.user_presets_path = "ConanPresets.json"
        tc.generate()
