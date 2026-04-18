#include <gtest/gtest.h>

#include <cpp_boilerplate/split.hpp>

#include <string_view>
#include <vector>

TEST(SplitTest, SplitsCommaSeparatedFields)
{
    const std::vector<std::string_view> expected{"52930489", "aaa", "18", "1222"};
    EXPECT_EQ(cpp_boilerplate::split_views_vec("52930489,aaa,18,1222"), expected);
}

TEST(SplitTest, ReturnsSingleEmptyFieldForEmptyInput)
{
    const std::vector<std::string_view> expected{""};
    EXPECT_EQ(cpp_boilerplate::split_views_vec(""), expected);
}

TEST(SplitTest, ReturnsOriginalStringWhenDelimiterIsAbsent)
{
    const std::vector<std::string_view> expected{"no delimiter"};
    EXPECT_EQ(cpp_boilerplate::split_views_vec("no delimiter"), expected);
}

TEST(SplitTest, PreservesEmptyFieldsBetweenAdjacentDelimiters)
{
    const std::vector<std::string_view> expected{"alpha", "", "gamma"};
    EXPECT_EQ(cpp_boilerplate::split_views_vec("alpha,,gamma"), expected);
}

TEST(SplitTest, PreservesTrailingEmptyField)
{
    const std::vector<std::string_view> expected{"alpha", "beta", ""};
    EXPECT_EQ(cpp_boilerplate::split_views_vec("alpha,beta,"), expected);
}

TEST(SplitTest, SupportsCustomDelimiter)
{
    const std::vector<std::string_view> expected{"left", "middle", "right"};
    EXPECT_EQ(cpp_boilerplate::split_views_vec("left|middle|right", '|'), expected);
}
