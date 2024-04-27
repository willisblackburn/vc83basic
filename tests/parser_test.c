#include "test.h"

void test_char_to_digit(void) {
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

int call_read_number(const char* s, char set_buffer_pos) {
    strcpy(buffer, s);
    buffer_pos = set_buffer_pos;
    return read_number();
}

void test_read_number(void) {
    int number;

    PRINT_TEST_NAME();

    number = call_read_number("10 PRINT X", 0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(number, 10);
    ASSERT_EQ(buffer_pos, 2);

    // The function should honor the current read position.
    number = call_read_number("1020 PRINT X", 2);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(number, 20);
    ASSERT_EQ(buffer_pos, 4);

    // The function should return carry set if an invalid number.
    call_read_number("invalid", 0);
    ASSERT_NE(err, 0);
    ASSERT_EQ(buffer_pos, 0);

    call_read_number("", 0);
    ASSERT_NE(err, 0);
    ASSERT_EQ(buffer_pos, 0);
}

void call_parse_keyword(const char* keyword, const char* s, char set_buffer_pos) {
    strcpy(buffer, s);
    buffer_pos = set_buffer_pos;
    parse_keyword(keyword);
}

void test_parse_keyword(void) {
    PRINT_TEST_NAME();

    call_parse_keyword("PRIN\xD4", "PRINT", 0); // \xD4 = 'T' with high bit set
    ASSERT_EQ(err, 0);
    call_parse_keyword("LIS\xD4", "PRINT", 0);
    ASSERT_NE(err, 0);
    call_parse_keyword("PRINTE\xD2", "PRINT", 0);
    ASSERT_NE(err, 0);
    call_parse_keyword("PRIN\xD4", "PRINT", 2);
    ASSERT_NE(err, 0);
}

int main(void) {
    initialize_target();
    test_char_to_digit();
    test_read_number();
    test_parse_keyword();
    return 0;
}