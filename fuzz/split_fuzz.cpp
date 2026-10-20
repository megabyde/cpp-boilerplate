// Splits the input at the delimiter its first byte names. The lazy and the materialized splits must
// agree, an input with n delimiters must give n + 1 fields (none when it is empty), and joining the
// fields with the delimiter must give the input back.

#include <cpp_boilerplate/split.hpp>

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <string>
#include <string_view>

namespace {

void check(bool condition)
{
    if (!condition) {
        std::abort();
    }
}

} // namespace

extern "C" int LLVMFuzzerTestOneInput(const std::uint8_t* data, std::size_t size)
{
    if (size == 0) {
        return 0;
    }
    const auto delimiter = static_cast<char>(data[0]);
    // NOLINTNEXTLINE(cppcoreguidelines-pro-type-reinterpret-cast)
    const std::string_view record(reinterpret_cast<const char*>(data) + 1, size - 1);

    const auto fields = cpp_boilerplate::split_views_vec(record, delimiter);
    check(std::ranges::equal(fields, cpp_boilerplate::split_views(record, delimiter)));
    const auto delimiters = static_cast<std::size_t>(std::ranges::count(record, delimiter));
    check(fields.size() == (record.empty() ? 0 : delimiters + 1));

    std::string joined;
    for (std::size_t i = 0; i < fields.size(); ++i) {
        if (i != 0) {
            joined += delimiter;
        }
        joined += fields[i];
    }
    check(joined == record);
    return 0;
}
