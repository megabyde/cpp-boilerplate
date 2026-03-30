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

find_package(Threads REQUIRED)
find_package(Boost REQUIRED)

function(enable_project_warnings target)
    if(MSVC)
        target_compile_options(${target} PRIVATE /W4 /WX /permissive- /EHsc)
    else()
        target_compile_options(${target} PRIVATE -Wall -Wextra -Wpedantic -Werror)
    endif()
endfunction()

add_executable(cpp-boilerplate src/main.cpp)
target_compile_features(cpp-boilerplate PRIVATE cxx_std_23)
target_include_directories(cpp-boilerplate PRIVATE ${PROJECT_SOURCE_DIR}/include)
target_link_libraries(
    cpp-boilerplate
    PRIVATE
        Boost::headers
        Threads::Threads
)
enable_project_warnings(cpp-boilerplate)

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
    gtest_discover_tests(split_test)
endif()
