#pragma once

#include <string>
#include <string_view>
#include <vector>

namespace cpp_boilerplate {

inline std::vector<std::string_view>
split_views(std::string_view record, char delimiter = ',')
{
    std::vector<std::string_view> fields;

    std::size_t begin = 0;

    for (;;) {
        std::size_t end = record.find(delimiter, begin);
        fields.emplace_back(record.substr(begin, end - begin));
        if (end == std::string_view::npos) {
            break;
        }
        begin = end + 1;
    }

    return fields;
}

inline std::vector<std::string>
split(std::string_view record, char delimiter = ',')
{
    std::vector<std::string> fields;

    for (std::string_view field : split_views(record, delimiter)) {
        fields.emplace_back(field);
    }

    return fields;
}

} // namespace cpp_boilerplate
