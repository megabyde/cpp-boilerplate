# 3.25 is the floor bound by the features this template uses: workflow presets and
# CMakePresets schema v6 (3.25), COMPILE_WARNING_AS_ERROR (3.24), cxx_std_23 (3.20).
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

option(WARNINGS_AS_ERRORS "Treat warnings as errors" ON)
option(ENABLE_SANITIZERS "Enable sanitizer instrumentation" OFF)
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

function(enable_sanitizers target)
    if(NOT ENABLE_SANITIZERS)
        return()
    endif()

    if(MSVC)
        # MSVC ships AddressSanitizer; UndefinedBehaviorSanitizer is not available.
        target_compile_options(${target} PRIVATE /fsanitize=address)
    elseif(CMAKE_CXX_COMPILER_ID MATCHES "^(GNU|Clang|AppleClang)$")
        target_compile_options(
            ${target} PRIVATE -fsanitize=address,undefined -fno-sanitize-recover=all
                              -fno-omit-frame-pointer
        )
        target_link_options(${target} PRIVATE -fsanitize=address,undefined)
    else()
        message(FATAL_ERROR "Sanitizers require MSVC, GCC, Clang, or AppleClang")
    endif()
endfunction()

function(enable_coverage target)
    if(NOT ENABLE_COVERAGE)
        return()
    endif()

    if(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
        # Clang and AppleClang: source-based coverage, read by llvm-cov.
        target_compile_options(${target} PRIVATE -O0 -g -fprofile-instr-generate
                                                 -fcoverage-mapping
        )
        target_link_options(${target} PRIVATE -fprofile-instr-generate)
    elseif(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
        # GCC: gcov-based coverage, read by gcovr.
        target_compile_options(${target} PRIVATE -O0 -g --coverage)
        target_link_options(${target} PRIVATE --coverage)
    else()
        message(FATAL_ERROR "Coverage requires GCC, Clang, or AppleClang")
    endif()
endfunction()

function(enable_hardening target)
    # Instrumented builds skip hardening: _FORTIFY_SOURCE conflicts with the ASan
    # interceptors, and coverage builds run at -O0 where glibc fortify warns (fatal
    # under -Werror).
    if(NOT ENABLE_HARDENING
       OR ENABLE_SANITIZERS
       OR ENABLE_COVERAGE
    )
        return()
    endif()

    if(MSVC)
        # Control Flow Guard needs both compile and link; /GS is on by default.
        target_compile_options(${target} PRIVATE /guard:cf)
        target_link_options(${target} PRIVATE /guard:cf)
    elseif(CMAKE_CXX_COMPILER_ID MATCHES "^(GNU|Clang|AppleClang)$")
        # Stack protector always; fortified libc calls only in optimized configs
        # (fortify needs optimization, so Debug skips it). -U first: Ubuntu's gcc
        # predefines _FORTIFY_SOURCE when optimizing, and redefining it is fatal
        # under -Werror. Compile options, not definitions, to keep the -U/-D order.
        target_compile_options(
            ${target} PRIVATE -fstack-protector-strong
            $<$<NOT:$<CONFIG:Debug>>:-U_FORTIFY_SOURCE;-D_FORTIFY_SOURCE=2>
        )
    endif()
    # Other compilers fall through and build unhardened.
endfunction()

function(enable_project_options target)
    enable_project_warnings(${target})
    enable_sanitizers(${target})
    enable_coverage(${target})
    enable_hardening(${target})
endfunction()

# --- library ---------------------------------------------------------------
# Non-main code lives in a library so the application and the tests link the same
# artifact instead of recompiling sources. Include dirs and the language standard
# are PUBLIC so both consumers inherit them.
add_library(cpp_boilerplate_lib STATIC src/split.cpp)
target_include_directories(cpp_boilerplate_lib PUBLIC ${PROJECT_SOURCE_DIR}/include)
target_compile_features(cpp_boilerplate_lib PUBLIC cxx_std_23)
enable_project_options(cpp_boilerplate_lib)

# --- application -----------------------------------------------------------
# Generate a version header from the project() version (the single source of truth; the Conan
# recipe reads the same value) and expose it to the application only.
configure_file(
    ${PROJECT_SOURCE_DIR}/cmake/version.hpp.in
    ${PROJECT_BINARY_DIR}/generated/cpp_boilerplate/version.hpp @ONLY
)

add_executable(cpp_boilerplate src/main.cpp)
target_include_directories(cpp_boilerplate PRIVATE ${PROJECT_BINARY_DIR}/generated)
target_link_libraries(cpp_boilerplate PRIVATE cpp_boilerplate_lib spdlog::spdlog)
enable_project_options(cpp_boilerplate)

# Install only the application binary. The static library is an internal build artifact,
# not a public deliverable, so it is deliberately not installed or exported.
include(GNUInstallDirs)
install(TARGETS cpp_boilerplate RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})

# --- tests -----------------------------------------------------------------
if(BUILD_TESTING)
    find_package(GTest CONFIG REQUIRED)
    include(GoogleTest)
    add_executable(split_test tests/split_test.cpp)
    target_link_libraries(split_test PRIVATE cpp_boilerplate_lib GTest::gtest_main)
    enable_project_options(split_test)

    # Each test process writes its own raw profile (%p pid, %m binary id) so the
    # source-based coverage data from all tests can be merged. Harmless for the
    # non-coverage presets, whose binaries are not instrumented.
    set(coverage_profile "LLVM_PROFILE_FILE=${CMAKE_BINARY_DIR}/profraw/%p-%m.profraw")

    gtest_discover_tests(split_test DISCOVERY_MODE PRE_TEST
                         PROPERTIES ENVIRONMENT "${coverage_profile}"
    )

    # Smoke test: the application binary runs to completion and exits cleanly.
    # Complements the unit tests by exercising src/main.cpp, including under the
    # sanitizer and coverage presets.
    add_test(NAME AppTest.RunsToCompletion COMMAND cpp_boilerplate)
    set_tests_properties(AppTest.RunsToCompletion PROPERTIES
                         PASS_REGULAR_EXPRESSION "done" ENVIRONMENT "${coverage_profile}"
    )
endif()
