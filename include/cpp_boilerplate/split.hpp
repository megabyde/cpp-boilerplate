#pragma once

#include <string>
#include <string_view>
#include <vector>

inline std::vector<std::string>
split(std::string_view record, char delimiter = ',')
{
    std::vector<std::string> fields;

    std::size_t begin = 0;
    std::size_t end   = 0;

    do {
        end = record.find(delimiter, begin);
        fields.emplace_back(record.substr(begin, end - begin));
        begin = end + 1;
    } while (end != std::string_view::npos);

    return fields;
}
