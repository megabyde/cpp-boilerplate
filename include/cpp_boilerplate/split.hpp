#pragma once

#include <ranges>
#include <string_view>
#include <vector>

namespace cpp_boilerplate {

[[nodiscard]] constexpr auto split_views(std::string_view record, char delimiter = ',')
{
    return record | std::views::split(delimiter) | std::views::transform([](auto subrange) {
               return std::string_view(subrange.begin(), subrange.end());
           });
}

[[nodiscard]] std::vector<std::string_view> split_views_vec(std::string_view record,
                                                            char delimiter = ',');

} // namespace cpp_boilerplate
