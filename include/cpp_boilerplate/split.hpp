#pragma once

#include <string>
#include <string_view>
#include <vector>

inline std::vector<std::string>
split(std::string_view record, char delimiter = ',')
{
    std::vector<std::string> fields;

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
