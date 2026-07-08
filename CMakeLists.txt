# 3.25 is the floor bound by the features this template uses: workflow presets and CMakePresets
# schema v6 (3.25), COMPILE_WARNING_AS_ERROR (3.24), cxx_std_23 (3.20).
cmake_minimum_required(VERSION 3.25)

project(
    cpp_boilerplate
    VERSION 0.1.0
    DESCRIPTION "Modern C++23 project template with Conan and CMake"
    LANGUAGES CXX
)

include(CTest)

set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_COLOR_DIAGNOSTICS
    ON
    CACHE BOOL "Enable color diagnostics in generated build systems"
)

option(WARNINGS_AS_ERRORS "Treat warnings as errors" ON)
option(ENABLE_COVERAGE "Enable code coverage instrumentation" OFF)
option(ENABLE_HARDENING "Enable hardening compile and link flags" ON)

if(CMAKE_EXPORT_COMPILE_COMMANDS
   AND CMAKE_GENERATOR MATCHES "Ninja|Makefiles"
   AND NOT CMAKE_BINARY_DIR STREQUAL PROJECT_SOURCE_DIR
)
    file(REMOVE ${PROJECT_SOURCE_DIR}/compile_commands.json)
    file(CREATE_LINK ${CMAKE_BINARY_DIR}/compile_commands.json
         ${PROJECT_SOURCE_DIR}/compile_commands.json SYMBOLIC COPY_ON_ERROR
    )
endif()

find_package(spdlog CONFIG REQUIRED)
find_package(CLI11 CONFIG REQUIRED)

function(enable_project_warnings target)
    if(MSVC)
        target_compile_options(${target} PRIVATE /W4)
    else()
        target_compile_options(${target} PRIVATE -Wall -Wextra -Wpedantic)
    endif()
    if(WARNINGS_AS_ERRORS)
        # Adds /WX for MSVC and -Werror for GCC/Clang.
        set_target_properties(${target} PROPERTIES COMPILE_WARNING_AS_ERROR ON)
    endif()
endfunction()

function(enable_coverage target)
    if(NOT ENABLE_COVERAGE)
        return()
    endif()

    if(CMAKE_CXX_COMPILER_ID MATCHES "^(GNU|Clang|AppleClang)$")
        target_compile_options(${target} PRIVATE --coverage)
        target_link_options(${target} PRIVATE --coverage)
    else()
        message(FATAL_ERROR "Coverage requires GCC, Clang, or AppleClang")
    endif()
endfunction()

function(enable_hardening target)
    if(NOT ENABLE_HARDENING)
        return()
    endif()

    if(MSVC)
        # Control Flow Guard needs both compile and link; /GS is on by default.
        target_compile_options(${target} PRIVATE /guard:cf)
        target_link_options(${target} PRIVATE /guard:cf)
    elseif(CMAKE_CXX_COMPILER_ID MATCHES "^(GNU|Clang|AppleClang)$")
        # Stack protector always; fortified libc calls only in optimized configs (fortify needs
        # optimization, so Debug skips it). -U first: Ubuntu's gcc predefines _FORTIFY_SOURCE when
        # optimizing, and redefining it is fatal under -Werror. Compile options, not definitions, to
        # keep the -U/-D order.
        target_compile_options(
            ${target} PRIVATE -fstack-protector-strong
                              $<$<NOT:$<CONFIG:Debug>>:-U_FORTIFY_SOURCE;-D_FORTIFY_SOURCE=2>
        )
    endif()
    # Other compilers fall through and build unhardened.
endfunction()

function(enable_project_options target)
    enable_project_warnings(${target})
    enable_coverage(${target})
    enable_hardening(${target})
endfunction()

# --- library ---------------------------------------------------------------
# Non-main code lives in a library so the application and the tests link the same artifact instead
# of recompiling sources. Include dirs and the language standard are PUBLIC so both consumers
# inherit them.
add_library(cpp_boilerplate_lib STATIC src/split.cpp)
target_include_directories(cpp_boilerplate_lib PUBLIC ${PROJECT_SOURCE_DIR}/include)
target_compile_features(cpp_boilerplate_lib PUBLIC cxx_std_23)
enable_project_options(cpp_boilerplate_lib)

# --- application -----------------------------------------------------------
# Generate a version header from the project() version (the single source of truth; the Conan recipe
# reads the same value) and expose it to the application only.
configure_file(
    ${PROJECT_SOURCE_DIR}/cmake/version.hpp.in
    ${PROJECT_BINARY_DIR}/generated/cpp_boilerplate/version.hpp @ONLY
)

add_executable(cpp_boilerplate src/main.cpp)
target_include_directories(cpp_boilerplate PRIVATE ${PROJECT_BINARY_DIR}/generated)
target_link_libraries(cpp_boilerplate PRIVATE cpp_boilerplate_lib spdlog::spdlog CLI11::CLI11)
enable_project_options(cpp_boilerplate)

# Install only the application binary. The static library is an internal build artifact, not a
# public deliverable, so it is deliberately not installed or exported.
include(GNUInstallDirs)
install(TARGETS cpp_boilerplate RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})

# --- tests -----------------------------------------------------------------
if(BUILD_TESTING)
    find_package(GTest CONFIG REQUIRED)
    include(GoogleTest)
    add_executable(cpp_boilerplate_test tests/split_test.cpp)
    target_link_libraries(cpp_boilerplate_test PRIVATE cpp_boilerplate_lib GTest::gtest_main)
    enable_project_options(cpp_boilerplate_test)

    gtest_discover_tests(cpp_boilerplate_test DISCOVERY_MODE PRE_TEST)

    # Smoke tests: exercise the application binary end to end — the normal run, the --version and
    # --help branches, and the error path (unknown argument -> nonzero exit). Together they cover
    # all of src/main.cpp, including under the sanitizer and coverage presets.
    add_test(NAME AppTest.RunsToCompletion COMMAND cpp_boilerplate)
    set_tests_properties(AppTest.RunsToCompletion PROPERTIES PASS_REGULAR_EXPRESSION "done")

    add_test(NAME AppTest.PrintsVersion COMMAND cpp_boilerplate --version)
    set_tests_properties(
        AppTest.PrintsVersion PROPERTIES PASS_REGULAR_EXPRESSION "${PROJECT_VERSION}"
    )

    add_test(NAME AppTest.PrintsHelp COMMAND cpp_boilerplate --help)
    set_tests_properties(AppTest.PrintsHelp PROPERTIES PASS_REGULAR_EXPRESSION "OPTIONS")

    # WILL_FAIL inverts the exit-code check: the test passes because the app exits nonzero on an
    # unknown argument.
    add_test(NAME AppTest.RejectsUnknownArgument COMMAND cpp_boilerplate --bogus)
    set_tests_properties(AppTest.RejectsUnknownArgument PROPERTIES WILL_FAIL TRUE)
endif()
