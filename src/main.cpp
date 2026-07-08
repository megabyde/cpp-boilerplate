#include <cpp_boilerplate/split.hpp>
#include <cpp_boilerplate/version.hpp>

#include <CLI/CLI.hpp>
#include <spdlog/spdlog.h>

#include <cstddef>
#include <exception>
#include <string>
#include <string_view>

namespace {

void run()
{
    spdlog::set_pattern("[%Y-%m-%d %H:%M:%S.%e] [%^%l%$] %v");
    spdlog::info("cpp-boilerplate {} starting", cpp_boilerplate::version);

    constexpr std::string_view record = "alpha,beta,gamma";
    std::size_t index = 0;
    for (const auto field : cpp_boilerplate::split_views(record)) {
        spdlog::info("field {}: {}", index, field);
        ++index;
    }

    spdlog::info("done");
}

} // namespace

// CLI11 setup before the try block throws only on programmer error.
// NOLINTNEXTLINE(bugprone-exception-escape)
int main(int argc, char* argv[])
{
    CLI::App app{"Modern C++23 project template demo"};
    app.set_version_flag("--version", std::string{cpp_boilerplate::version});
    // Handles --help, --version, and argument errors, exiting with the right code.
    CLI11_PARSE(app, argc, argv);

    // Defensive scaffolding: nothing in the app throws today, so the handlers are
    // excluded from coverage rather than left as uncovered lines or tested through
    // artificial hooks.
    try {
        run();
        return 0;
        // LCOV_EXCL_START
    }
    catch (const std::exception& error) {
        spdlog::critical("fatal: {}", error.what());
    }
    catch (...) {
        spdlog::critical("fatal: unknown exception");
    }
    return 1;
    // LCOV_EXCL_STOP
}
