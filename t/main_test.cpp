/**
 * Tests for main
 */

#include "../main.h"

#include <gmock/gmock.h>

class SplitTest : public ::testing::Test {
protected:
    void SetUp() override {}
};

TEST_F(SplitTest, TestSplit)
{
    std::vector<std::string> expected{"52930489", "aaa", "18", "1222"};
    EXPECT_EQ(split("52930489,aaa,18,1222"), expected);
}

TEST_F(SplitTest, TestEmpty)
{
    std::vector<std::string> expected{""};
    EXPECT_EQ(split(""), expected);
}

TEST_F(SplitTest, TestNoDelimiter)
{
    std::vector<std::string> expected{"no delimiter"};
    EXPECT_EQ(split("no delimiter"), expected);
}
