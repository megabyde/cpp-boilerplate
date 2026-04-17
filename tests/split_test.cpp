#include <gtest/gtest.h>

#include <cpp_boilerplate/split.hpp>

#include <string_view>
#include <vector>

TEST(SplitTest, SplitsCommaSeparatedFields)
{
    const std::vector<std::string> expected{"52930489", "aaa", "18", "1222"};
    EXPECT_EQ(cpp_boilerplate::split("52930489,aaa,18,1222"), expected);
}

TEST(SplitTest, ReturnsSingleEmptyFieldForEmptyInput)
{
    const std::vector<std::string> expected{""};
    EXPECT_EQ(cpp_boilerplate::split(""), expected);
}

TEST(SplitTest, ReturnsOriginalStringWhenDelimiterIsAbsent)
{
    const std::vector<std::string> expected{"no delimiter"};
    EXPECT_EQ(cpp_boilerplate::split("no delimiter"), expected);
}

TEST(SplitTest, PreservesEmptyFieldsBetweenAdjacentDelimiters)
{
    const std::vector<std::string> expected{"alpha", "", "gamma"};
    EXPECT_EQ(cpp_boilerplate::split("alpha,,gamma"), expected);
}

TEST(SplitTest, PreservesTrailingEmptyField)
{
    const std::vector<std::string> expected{"alpha", "beta", ""};
    EXPECT_EQ(cpp_boilerplate::split("alpha,beta,"), expected);
}

TEST(SplitTest, SupportsCustomDelimiter)
{
    const std::vector<std::string> expected{"left", "middle", "right"};
    EXPECT_EQ(cpp_boilerplate::split("left|middle|right", '|'), expected);
}

TEST(SplitViewTest, ReturnsZeroCopyViews)
{
    const std::vector<std::string_view> expected{"52930489", "aaa", "18", "1222"};
    EXPECT_EQ(cpp_boilerplate::split_views("52930489,aaa,18,1222"), expected);
}
