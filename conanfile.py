import shutil

from conan import ConanFile
from conan.tools.cmake import CMakeConfigDeps, CMakeToolchain, cmake_layout


class CppBoilerplateConan(ConanFile):
    required_conan_version = ">=2.0"
    name = "cpp-boilerplate"
    version = "0.1.0"
    package_type = "application"

    settings = "os", "compiler", "build_type", "arch"

    requires = "spdlog/1.15.3"

    default_options = {
        "spdlog/*:header_only": False,
        "spdlog/*:shared": False,
        "spdlog/*:use_std_fmt": False,
    }

    def _cmake_generator(self):
        return "Ninja" if shutil.which("ninja") else "Unix Makefiles"

    def layout(self):
        cmake_layout(self, generator=self._cmake_generator())

    def build_requirements(self):
        self.test_requires("gtest/1.15.0")

    def generate(self):
        deps = CMakeConfigDeps(self)
        deps.generate()

        tc = CMakeToolchain(self, generator=self._cmake_generator())
        tc.user_presets_path = "ConanPresets.json"
        tc.generate()
