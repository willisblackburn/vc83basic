#include "test.h"

static void test_char_to_digit(void) {
    int err;

    PRINT_TEST_NAME();

    err = char_to_digit('0');
    ASSERT_EQ(err, 0);
    ASSERT_EQ(reg_a, 0);
    err = char_to_digit('9');
    ASSERT_EQ(err, 0);
    ASSERT_EQ(reg_a, 9);
    err = char_to_digit('0'-1);
    ASSERT_NE(err, 0);
    err = char_to_digit('9'+1);
    ASSERT_NE(err, 0);
    err = char_to_digit(' ');
    ASSERT_NE(err, 0);
    err = char_to_digit('A');
    ASSERT_NE(err, 0);
    err = char_to_digit(0);
    ASSERT_NE(err, 0);
    err = char_to_digit(255);
    ASSERT_NE(err, 0);
}

static void test_read_number(void) {
    int err;

    PRINT_TEST_NAME();

    set_buffer("10 PRINT X");
    err = read_number(0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(reg_ax, 10);

    // The function should honor the current read index.
    set_buffer("1020 PRINT X");
    err = read_number(2);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(reg_ax, 20);

    // The function should skip inital whitespace.
    set_buffer("  10000 PRINT X");
    err = read_number(0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(reg_ax, 10000);

    // The function should return carry set if an invalid number.
    set_buffer("invalid");
    err = read_number(0);
    ASSERT_NE(err, 0);

    // The function should not read past the end of the buffer.
    set_buffer("10000");
    buffer_length = 3;
    err = read_number(0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(reg_ax, 100);

    buffer_length = 0;
    err = read_number(0);
    ASSERT_NE(err, 0);
}

void test_parse_keyword(void) {
    int err;
    const char* print = "PRIN\xD4";

    PRINT_TEST_NAME();

    set_buffer("PRINT");
    err = parse_keyword("PRIN\xD4", 0); // \xD4 = 'T' with high bit set
    ASSERT_EQ(err, 0);
    err = parse_keyword("LIS\xD4", 0);
    ASSERT_NE(err, 0);
    err = parse_keyword("PRINTE\xD2", 0);
    ASSERT_NE(err, 0);
    err = parse_keyword("PRIN\xD4", 2);
    ASSERT_NE(err, 0);

    // The function should pay attention to buffer_length.
    buffer_length = 3;
    err = parse_keyword("PRIN\xD4", 0); // \xD4 = 'T' with high bit set
    ASSERT_NE(err, 0);
}

int main(void) {
    initialize_arch();
    test_char_to_digit();
    test_read_number();
    test_parse_keyword();
    return 0;
}