#pragma once

#include <boost/algorithm/string/join.hpp>
#include <boost/algorithm/string/trim.hpp>

#include <cpp_boilerplate/split.hpp>

#include <string>
#include <string_view>
#include <vector>

inline std::string
summarize_fields(std::string_view record, char delimiter = ',', std::string_view separator = " | ")
{
    std::vector<std::string> fields = split(record, delimiter);

    for (std::string& field : fields) {
        boost::algorithm::trim(field);
    }

    return boost::algorithm::join(fields, std::string{separator});
}
