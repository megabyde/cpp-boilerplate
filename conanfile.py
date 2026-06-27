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
        return "Ninja" if shutil.which("ninja") else "Unix Makefiles"

    def layout(self):
        # The sanitize build shares Debug settings and is distinguished only by the
        # compiler.sanitizer setting (see conan/settings_user.yml).
        sanitize = bool(self.settings.get_safe("compiler.sanitizer"))
        if sanitize:
            # Names the generated Conan preset conan-sanitize-debug, which the
            # checked-in CMakePresets sanitize preset inherits.
            self.folders.build_folder_vars = ["const.sanitize"]
        cmake_layout(self, generator=self._cmake_generator(), build_folder="build")
        # Flatten the generator output into build/<preset> so the paths line up with
        # the checked-in CMakePresets binaryDir/toolchainFile.
        folder = "build/sanitize" if sanitize else f"build/{str(self.settings.build_type).lower()}"
        self.folders.build = folder
        self.folders.generators = f"{folder}/generators"

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
