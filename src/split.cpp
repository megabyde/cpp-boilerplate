#include <cpp_boilerplate/split.hpp>

#include <ranges>
#include <string_view>
#include <vector>

#if !defined(__cpp_lib_ranges_to_container) || __cpp_lib_ranges_to_container < 202202L
#error "cpp-boilerplate requires C++23 std::ranges::to support"
#endif

namespace cpp_boilerplate {

std::vector<std::string_view> split_views_vec(std::string_view record, char delimiter)
{
    return split_views(record, delimiter) | std::ranges::to<std::vector>();
}

} // namespace cpp_boilerplate
