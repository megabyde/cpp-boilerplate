import shutil

from conan import ConanFile
from conan.tools.cmake import CMakeDeps, CMakeToolchain, cmake_layout


class CppBoilerplateConan(ConanFile):
    required_conan_version = ">=2.0"
    name = "cpp-boilerplate"
    version = "0.1.0"
    package_type = "application"

    settings = "os", "compiler", "build_type", "arch"
    options = {
        "asan": [True, False],
        "coverage": [True, False],
        "with_tests": [True, False],
    }

    requires = "boost/1.90.0"

    default_options = {
        "asan": False,
        "coverage": False,
        "with_tests": True,
        "boost/*:header_only": True,
    }

    def _cmake_generator(self):
        if str(self.settings.os) == "Windows":
            return "Visual Studio 17 2022"

        return "Ninja" if shutil.which("ninja") else "Unix Makefiles"

    def layout(self):
        build_variants = []
        if self.options.get_safe("asan"):
            build_variants.append("asan")
        if self.options.get_safe("coverage"):
            build_variants.append("coverage")
        self.build_variant = "-".join(build_variants) if build_variants else None
        self.folders.build_folder_vars = ["settings.build_type", "self.build_variant"]
        cmake_layout(self, generator=self._cmake_generator())

    def build_requirements(self):
        if self.options.with_tests:
            self.test_requires("gtest/1.15.0")

    def generate(self):
        deps = CMakeDeps(self)
        deps.generate()

        tc = CMakeToolchain(self, generator=self._cmake_generator())
        tc.user_presets_path = "ConanPresets.json"
        tc.cache_variables["BUILD_TESTING"] = bool(self.options.with_tests)
        tc.cache_variables["ENABLE_ASAN"] = bool(self.options.asan)
        tc.cache_variables["ENABLE_COVERAGE"] = bool(self.options.coverage)
        tc.generate()
