#include <iostream>
#include <thread>

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
    std::jthread worker{hello};
    return 0;
}
