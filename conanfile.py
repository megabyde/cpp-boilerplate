import shutil

from conan import ConanFile
from conan.tools.cmake import CMakeConfigDeps, CMakeToolchain, cmake_layout


class CppBoilerplateConan(ConanFile):
    required_conan_version = ">=2.5"
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
        return "Ninja" if shutil.which("ninja") else "Unix Makefiles"

    def layout(self):
        cmake_layout(self, generator=self._cmake_generator(), build_folder="build")
        bt = str(self.settings.build_type).lower()
        self.folders.build = f"build/{bt}"
        self.folders.generators = f"{self.folders.build}/generators"

    def build_requirements(self):
        self.test_requires("gtest/1.15.0")

    def generate(self):
        # CMakeConfigDeps (Conan 2.x) generates CMake CONFIG find_package files under
        # the build dir. Preferred over the legacy CMakeDeps generator.
        deps = CMakeConfigDeps(self)
        deps.generate()

        tc = CMakeToolchain(self, generator=self._cmake_generator())
        tc.user_presets_path = "ConanPresets.json"
        tc.generate()
