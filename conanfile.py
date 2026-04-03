from conan import ConanFile
from conan.tools.cmake import cmake_layout


class CppBoilerplateConan(ConanFile):
    required_conan_version = ">=2.0"
    name = "cpp-boilerplate"
    version = "0.1.0"
    package_type = "application"

    settings = "os", "compiler", "build_type", "arch"
    generators = "CMakeDeps", "CMakeToolchain"

    requires = "boost/1.90.0"
    test_requires = "gtest/1.15.0"

    default_options = {
        "boost/*:header_only": True,
    }

    def layout(self):
        cmake_layout(self)
        self.folders.build = "."
        self.folders.generators = "."
