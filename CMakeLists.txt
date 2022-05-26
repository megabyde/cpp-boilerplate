cmake_minimum_required(VERSION 3.5)
project(cpp-boilerplate CXX)

enable_testing()

find_package(Threads REQUIRED)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_CXX_STANDARD 17)
# Prevent overriding the parent project's compiler/linker settings on Windows
set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)

if(MSVC)
  add_compile_options(/W4 /wd4100 /WX /EHsc)
else()
  add_compile_options(-Wall -Wextra -Werror -Wno-unused-parameter)
endif()

add_subdirectory(t)
add_subdirectory(external/googletest)

add_executable(cpp-boilerplate main.cpp)
target_link_libraries(cpp-boilerplate ${CMAKE_THREAD_LIBS_INIT})
