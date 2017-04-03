cmake_minimum_required(VERSION 3.5)
project(cpp-boilerplate CXX C)

enable_testing()

find_package(Threads)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_CXX_STANDARD 14)
# Prevent overriding the parent project's compiler/linker settings on Windows
set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)

if(MSVC)
  set(CMAKE_CXX_FLAGS "/W4 /wd4100 /WX /EHsc")
else()
  set(CMAKE_CXX_FLAGS "-Wall -Wextra -Wno-unused-parameter -Wno-sign-compare -Werror")
endif()

add_subdirectory(t)
add_subdirectory(external/googletest)

set(SOURCE_FILES main.cpp)
add_executable(cpp-boilerplate ${SOURCE_FILES})
target_link_libraries (cpp-boilerplate ${CMAKE_THREAD_LIBS_INIT})
