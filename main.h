#pragma once

#include <sstream>
#include <string>
#include <vector>

/**
 * Utility function to split a string by the delimiter
 */
std::vector<std::string>
split(const std::string& s, char delimiter = ',')
{
    std::vector<std::string> tokens;

    size_t begin = 0, end;
    do {
        end = s.find_first_of(delimiter, begin);
        tokens.emplace_back(s.substr(begin, end - begin));
        begin = end + 1;
    } while (end < std::string::npos);

    return tokens;
}
