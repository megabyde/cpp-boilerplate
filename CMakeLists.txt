cmake_minimum_required(VERSION 3.5)
project(cpp-boilerplate CXX C)

enable_testing()

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_CXX_FLAGS "-Wall -Wextra -Wno-unused-parameter -Wno-sign-compare -Werror")
set(CMAKE_CXX_STANDARD 14)
find_package(Threads)

add_subdirectory(t)
add_subdirectory(external/googletest)

set(SOURCE_FILES main.cpp)
add_executable(cpp-boilerplate ${SOURCE_FILES})
target_link_libraries (cpp-boilerplate ${CMAKE_THREAD_LIBS_INIT})
