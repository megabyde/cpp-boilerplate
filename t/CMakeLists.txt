add_executable(main_test main_test.cpp)
add_test(main_test main_test)
target_link_libraries(main_test gtest gmock gmock_main)
