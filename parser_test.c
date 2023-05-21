#include "test.h"

static void test_char_to_digit(void) {
    char d;

    PRINT_TEST_NAME();

    d = char_to_digit('0');
    ASSERT_EQ(err, 0);
    ASSERT_EQ(d, 0);
    d = char_to_digit('9');
    ASSERT_EQ(err, 0);
    ASSERT_EQ(d, 9);
    char_to_digit('0'-1);
    ASSERT_NE(err, 0);
    char_to_digit('9'+1);
    ASSERT_NE(err, 0);
    char_to_digit(' ');
    ASSERT_NE(err, 0);
    char_to_digit('A');
    ASSERT_NE(err, 0);
    char_to_digit(0);
    ASSERT_NE(err, 0);
    char_to_digit(255);
    ASSERT_NE(err, 0);
}

static void test_read_number(void) {
    int number;

    PRINT_TEST_NAME();

    strcpy(buffer, "10 PRINT X");
    number = read_number(0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(number, 10);
    ASSERT_EQ(bp, 2);

    // The function should honor the current read position.
    strcpy(buffer, "1020 PRINT X");
    number = read_number(2);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(number, 20);
    ASSERT_EQ(bp, 4);

    // The function should return carry set if an invalid number.
    strcpy(buffer, "invalid");
    read_number(0);
    ASSERT_NE(err, 0);
    ASSERT_EQ(bp, 0);

    strcpy(buffer, "");
    read_number(0);
    ASSERT_NE(err, 0);
    ASSERT_EQ(bp, 0);
}

static void test_parse_keyword(void) {
    const char* print = "PRIN\xD4";

    PRINT_TEST_NAME();

    strcpy(buffer, "PRINT");
    parse_keyword("PRIN\xD4", 0); // \xD4 = 'T' with high bit set
    ASSERT_EQ(err, 0);
    parse_keyword("LIS\xD4", 0);
    ASSERT_NE(err, 0);
    parse_keyword("PRINTE\xD2", 0);
    ASSERT_NE(err, 0);
    parse_keyword("PRIN\xD4", 2);
    ASSERT_NE(err, 0);
}

int main(void) {
    initialize_target();
    test_char_to_digit();
    test_read_number();
    test_parse_keyword();
    return 0;
}