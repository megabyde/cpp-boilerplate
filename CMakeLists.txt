cmake_minimum_required(VERSION 3.28)

project(
    cpp_boilerplate
    VERSION 0.1.0
    DESCRIPTION "Modern C++23 project template with Conan and CMake"
    LANGUAGES CXX
)

include(CTest)

set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

option(WARNINGS_AS_ERRORS "Treat warnings as errors" OFF)
option(ENABLE_SANITIZERS "Enable sanitizer instrumentation" OFF)
option(ENABLE_COVERAGE "Enable code coverage instrumentation" OFF)

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
    target_compile_options(${target} PRIVATE -Wall -Wextra -Wpedantic)
    if(WARNINGS_AS_ERRORS)
        set_target_properties(${target} PROPERTIES COMPILE_WARNING_AS_ERROR ON)
    endif()
endfunction()

function(enable_sanitizers target)
    if(NOT ENABLE_SANITIZERS)
        return()
    endif()

    if(NOT CMAKE_CXX_COMPILER_ID MATCHES "^(GNU|Clang|AppleClang)$")
        message(FATAL_ERROR "Sanitizers require GCC, Clang, or AppleClang")
    endif()

    target_compile_options(
        ${target} PRIVATE -fsanitize=address,undefined -fno-sanitize-recover=all
                          -fno-omit-frame-pointer
    )
    target_link_options(${target} PRIVATE -fsanitize=address,undefined)
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

function(enable_project_options target)
    enable_project_warnings(${target})
    enable_sanitizers(${target})
    enable_coverage(${target})
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
add_executable(cpp_boilerplate src/main.cpp)
target_link_libraries(cpp_boilerplate PRIVATE cpp_boilerplate_lib spdlog::spdlog)
enable_project_options(cpp_boilerplate)

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
