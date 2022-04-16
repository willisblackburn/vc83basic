#include "test.h"

void test_is_name_character() {
    int err;

    PRINT_TEST_NAME();

    err = is_name_character('$');
    ASSERT_EQ(err, 0);
    err = is_name_character('A');
    ASSERT_EQ(err, 0);
    err = is_name_character('Z');
    ASSERT_EQ(err, 0);
    err = is_name_character('0');
    ASSERT_EQ(err, 0);
    err = is_name_character('9');
    ASSERT_EQ(err, 0);
    err = is_name_character('#');
    ASSERT_NE(err, 0);
    err = is_name_character('%');
    ASSERT_NE(err, 0);
    err = is_name_character('@');
    ASSERT_NE(err, 0);
    err = is_name_character('[');
    ASSERT_NE(err, 0);
    err = is_name_character('/');
    ASSERT_NE(err, 0);
    err = is_name_character(':');
    ASSERT_NE(err, 0);
    err = is_name_character(' ');
    ASSERT_NE(err, 0);
    err = is_name_character(0);
    ASSERT_NE(err, 0);
    err = is_name_character(0x7F);
    ASSERT_NE(err, 0);
    err = is_name_character(0x80);
    ASSERT_NE(err, 0);
    err = is_name_character(0xFF);
    ASSERT_NE(err, 0);
}

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
    err = find_name("PRIN\xD4", 0); // \xD4 = 'T' with bit 7 set
    ASSERT_EQ(err, 0);
    ASSERT_EQ(reg_a, 0);
    ASSERT_EQ(reg_y, 5);
    ASSERT_EQ(r, 5);
    err = find_name("PRIN\xD4LIS\xD4", 0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(reg_a, 0);
    ASSERT_EQ(reg_y, 5);
    ASSERT_EQ(r, 5);
    err = find_name("LIS\xD4PRIN\xD4", 0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(reg_a, 1);
    ASSERT_EQ(reg_y, 5);
    ASSERT_EQ(r, 5);

    // Make sure find_name matches names that have some extra data.
    err = find_name("LIST\xD4PRINT\x11TO\x91", 0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(r, 5);
    ASSERT_EQ(reg_a, 1);
    ASSERT_EQ(reg_y, 5);

    // Name not found
    err = find_name("LIS\xD4", 0);
    ASSERT_NE(err, 0);
    ASSERT_EQ(r, 0);

    // Name in name table is longer than input namne
    err = find_name("PRINTE\xD2", 0);
    ASSERT_NE(err, 0);
    ASSERT_EQ(r, 0);
    err = find_name("LIS\xD4PRINTE\xD2", 0);
    ASSERT_NE(err, 0);
    ASSERT_EQ(r, 0);

    // Input name is longer than name in table
    err = find_name("PRI\xCE", 0);
    ASSERT_NE(err, 0);
    ASSERT_EQ(r, 0);
    err = find_name("LIS\xD4PRI\xCE", 0);
    ASSERT_NE(err, 0);
    ASSERT_EQ(r, 0);

    // Read position is not zero
    err = find_name("PRIN\xD4", 2);
    ASSERT_NE(err, 0);
    ASSERT_EQ(r, 2);
}

int main(void) {
    initialize_target();
    test_is_name_character();
    test_match_character_sequence();
    test_find_name();
    return 0;
}