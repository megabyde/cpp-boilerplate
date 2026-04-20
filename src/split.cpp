#include <cpp_boilerplate/split.hpp>

#include <string_view>
#include <vector>

namespace cpp_boilerplate {

std::vector<std::string_view> split_views_vec(std::string_view record, char delimiter)
{
    auto view = split_views(record, delimiter);
    return {view.begin(), view.end()};
}

} // namespace cpp_boilerplate
