#include <gtest/gtest.h>

#include <cpp_boilerplate/record_summary.hpp>
#include <cpp_boilerplate/split.hpp>

TEST(SplitTest, SplitsCommaSeparatedFields)
{
    std::vector<std::string> expected{"52930489", "aaa", "18", "1222"};
    EXPECT_EQ(split("52930489,aaa,18,1222"), expected);
}

TEST(SplitTest, ReturnsSingleEmptyFieldForEmptyInput)
{
    std::vector<std::string> expected{""};
    EXPECT_EQ(split(""), expected);
}

TEST(SplitTest, ReturnsOriginalStringWhenDelimiterIsAbsent)
{
    std::vector<std::string> expected{"no delimiter"};
    EXPECT_EQ(split("no delimiter"), expected);
}

TEST(SplitTest, PreservesEmptyFieldsBetweenAdjacentDelimiters)
{
    std::vector<std::string> expected{"alpha", "", "gamma"};
    EXPECT_EQ(split("alpha,,gamma"), expected);
}

TEST(SplitTest, PreservesTrailingEmptyField)
{
    std::vector<std::string> expected{"alpha", "beta", ""};
    EXPECT_EQ(split("alpha,beta,"), expected);
}

TEST(SplitTest, SupportsCustomDelimiter)
{
    std::vector<std::string> expected{"left", "middle", "right"};
    EXPECT_EQ(split("left|middle|right", '|'), expected);
}

TEST(RecordSummaryTest, TrimsWhitespaceBeforeJoiningFields)
{
    EXPECT_EQ(summarize_fields("  red, green , blue  "), "red | green | blue");
}

TEST(RecordSummaryTest, PreservesExplicitlyEmptyFields)
{
    EXPECT_EQ(summarize_fields("alpha, , gamma"), "alpha |  | gamma");
}

TEST(RecordSummaryTest, SupportsCustomDelimiters)
{
    EXPECT_EQ(summarize_fields(" left | middle | right ", '|', " -> "), "left -> middle -> right");
}
