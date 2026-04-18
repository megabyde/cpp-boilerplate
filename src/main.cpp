#include <cpp_boilerplate/split.hpp>

#include <spdlog/spdlog.h>

#include <cstddef>
#include <exception>
#include <string_view>

namespace {

void run()
{
    spdlog::set_pattern("[%Y-%m-%d %H:%M:%S.%e] [%^%l%$] %v");
    spdlog::info("cpp-boilerplate starting");

    constexpr std::string_view record = "alpha,beta,gamma";
    std::size_t index = 0;
    for (const auto field : cpp_boilerplate::split_views(record)) {
        spdlog::info("field {}: {}", index, field);
        ++index;
    }

    spdlog::info("done");
}

} // namespace

// NOLINTNEXTLINE(bugprone-exception-escape)
int main()
{
    try {
        run();
        return 0;
    }
    catch (const std::exception& error) {
        spdlog::critical("fatal: {}", error.what());
    }
    catch (...) {
        spdlog::critical("fatal: unknown exception");
    }
    return 1;
}
