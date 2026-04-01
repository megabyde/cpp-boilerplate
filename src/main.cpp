#include <iostream>
#include <exception>

#include <cpp_boilerplate/record_summary.hpp>

namespace {

void
hello()
{
    std::cout << "Hello World!\n";
    std::cout << "Boost summary: " << summarize_fields("  red, green , blue  ") << '\n';
}

} // namespace

int
main()
{
    try {
        hello();
        return 0;
    }
    catch (const std::exception& error) {
        std::cerr << "fatal error: " << error.what() << '\n';
    }

    return 1;
}
