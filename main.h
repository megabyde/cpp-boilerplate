#ifndef MAIN_H
#define MAIN_H

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
    std::stringstream        ss(s);
    std::string              token;

    while (getline(ss, token, delimiter)) {
        tokens.push_back(token);
    }
    return tokens;
}

#endif // MAIN_H
