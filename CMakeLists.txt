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

    if(NOT CMAKE_CXX_COMPILER_ID MATCHES "^(GNU|Clang|AppleClang)$")
        message(FATAL_ERROR "Coverage instrumentation requires GCC, Clang, or AppleClang")
    endif()

    target_compile_options(${target} PRIVATE -O0 -g --coverage)
    target_link_options(${target} PRIVATE --coverage)
endfunction()

add_executable(cpp_boilerplate src/main.cpp src/split.cpp)
target_compile_features(cpp_boilerplate PRIVATE cxx_std_23)
target_include_directories(cpp_boilerplate PRIVATE ${PROJECT_SOURCE_DIR}/include)
target_link_libraries(cpp_boilerplate PRIVATE spdlog::spdlog)
enable_project_warnings(cpp_boilerplate)
enable_sanitizers(cpp_boilerplate)
enable_coverage(cpp_boilerplate)

# --- tests -----------------------------------------------------------------
if(BUILD_TESTING)
    find_package(GTest CONFIG REQUIRED)
    include(GoogleTest)
    add_executable(split_test tests/split_test.cpp src/split.cpp)
    target_compile_features(split_test PRIVATE cxx_std_23)
    target_include_directories(split_test PRIVATE ${PROJECT_SOURCE_DIR}/include)
    target_link_libraries(split_test PRIVATE GTest::gtest_main)
    enable_project_warnings(split_test)
    enable_sanitizers(split_test)
    enable_coverage(split_test)
    gtest_discover_tests(split_test DISCOVERY_MODE PRE_TEST)
endif()
