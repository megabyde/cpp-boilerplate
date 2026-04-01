cmake_minimum_required(VERSION 3.28)

project(
    cpp-boilerplate
    VERSION 0.1.0
    DESCRIPTION "Modern C++ boilerplate with Conan and CMake presets"
    LANGUAGES CXX
)

include(CTest)

set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

option(CPP_BOILERPLATE_ENABLE_COVERAGE "Enable code coverage instrumentation" OFF)

if(CMAKE_EXPORT_COMPILE_COMMANDS)
    file(REMOVE ${PROJECT_SOURCE_DIR}/compile_commands.json)
    file(
        CREATE_LINK
        ${CMAKE_BINARY_DIR}/compile_commands.json
        ${PROJECT_SOURCE_DIR}/compile_commands.json
        SYMBOLIC
        COPY_ON_ERROR
    )
endif()

find_package(Boost REQUIRED)

function(enable_project_warnings target)
    if(MSVC)
        target_compile_options(${target} PRIVATE /W4 /WX /permissive- /EHsc)
    else()
        target_compile_options(${target} PRIVATE -Wall -Wextra -Wpedantic -Werror)
    endif()
endfunction()

function(enable_coverage target)
    if(NOT CPP_BOILERPLATE_ENABLE_COVERAGE)
        return()
    endif()

    if(NOT CMAKE_CXX_COMPILER_ID MATCHES "^(GNU|Clang|AppleClang)$")
        message(FATAL_ERROR "Coverage instrumentation requires GCC, Clang, or AppleClang")
    endif()

    target_compile_options(${target} PRIVATE -O0 -g --coverage)
    target_link_options(${target} PRIVATE --coverage)
endfunction()

add_executable(cpp-boilerplate src/main.cpp)
target_compile_features(cpp-boilerplate PRIVATE cxx_std_23)
target_include_directories(cpp-boilerplate PRIVATE ${PROJECT_SOURCE_DIR}/include)
target_link_libraries(
    cpp-boilerplate
    PRIVATE
        Boost::headers
)
enable_project_warnings(cpp-boilerplate)
enable_coverage(cpp-boilerplate)

if(BUILD_TESTING)
    find_package(GTest CONFIG REQUIRED)
    include(GoogleTest)

    add_executable(split_test tests/split_test.cpp)
    target_compile_features(split_test PRIVATE cxx_std_23)
    target_include_directories(split_test PRIVATE ${PROJECT_SOURCE_DIR}/include)
    target_link_libraries(
        split_test
        PRIVATE
            Boost::headers
            GTest::gtest_main
    )
    enable_project_warnings(split_test)
    enable_coverage(split_test)
    gtest_discover_tests(split_test)
endif()
