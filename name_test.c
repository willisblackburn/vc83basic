#include "test.h"

void test_match_character_sequence() {
    int err;

    PRINT_TEST_NAME();

    set_buffer("PRINT");
    err = match_character_sequence("PRIN\xD4", 0, 0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(reg_y, 5);
    ASSERT_EQ(r, 5);
}

void test_find_name(void) {
    int err;

    PRINT_TEST_NAME();

    // C adds a trailing 0 to these strings which terminates the name table.
    set_buffer("PRINT");
    err = find_name("PRIN\xD4", 0); // \xD4 = 'T' with high bit set
    ASSERT_EQ(err, 0);
    ASSERT_EQ(reg_ax, 0);
    ASSERT_EQ(reg_y, 5);
    ASSERT_EQ(r, 5);
    err = find_name("PRIN\xD4LIS\xD4", 0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(reg_ax, 0);
    ASSERT_EQ(reg_y, 5);
    ASSERT_EQ(r, 5);
    err = find_name("LIS\xD4PRIN\xD4", 0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(reg_ax, 1);
    ASSERT_EQ(reg_y, 5);
    ASSERT_EQ(r, 5);
    err = find_name("LIS\xD4", 0);
    ASSERT_NE(err, 0);
    ASSERT_EQ(r, 0);
    err = find_name("PRINTE\xD2", 0);
    ASSERT_NE(err, 0);
    ASSERT_EQ(r, 0);
    err = find_name("LIS\xD4PRINTE\xD2", 0);
    ASSERT_NE(err, 0);
    ASSERT_EQ(r, 0);
    err = find_name("PRIN\xD4", 2);
    ASSERT_NE(err, 0);
    ASSERT_EQ(r, 2);
}

int main(void) {
    initialize_target();
    test_match_character_sequence();
    test_find_name();
    return 0;
}