/**
 * Tests for main
 */

#include "../main.h"

#include <gmock/gmock.h>

class MainTest : public ::testing::Test {
protected:
    void SetUp() override {}
};

TEST_F(MainTest, TestSplit)
{
    std::vector<std::string> expected{"52930489", "aaa", "18", "1222"};
    EXPECT_EQ(split("52930489,aaa,18,1222"), expected);
}
