#pragma once

#include <boost/algorithm/string/join.hpp>
#include <boost/algorithm/string/trim.hpp>

#include <cpp_boilerplate/split.hpp>

#include <ranges>
#include <string>
#include <string_view>
#include <vector>

inline std::string
summarize_fields(std::string_view record, char delimiter = ',', std::string_view separator = " | ")
{
    std::vector<std::string> fields;

    for (std::string field : split_views(record, delimiter)
                                 | std::views::transform([](std::string_view value) {
                                       return std::string{value};
                                   })) {
        boost::algorithm::trim(field);
        fields.push_back(std::move(field));
    }

    return boost::algorithm::join(fields, std::string{separator});
}
