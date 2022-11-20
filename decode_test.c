#include "test.h"

static void test_decode_byte(void) {
    char byte_value;
    Line line = {
        6,
        10,
        { 0x00, 0x01, 0x03 }
    };

    PRINT_TEST_NAME();

    line_ptr = &line;
    lp = offsetof(Line, data);

    byte_value = decode_byte();
    ASSERT_EQ(byte_value, 0x00);

    byte_value = decode_byte();
    ASSERT_EQ(byte_value, 0x01);

    byte_value = decode_byte();
    ASSERT_EQ(byte_value, 0x03);
}

static void test_decode_number(void) {
    int value;
    Line line = {
        12,
        10,
        {  TOKEN_NUM, 0, 0, TOKEN_NUM, 0, 1, TOKEN_NUM, 1, 3 }
    };

    PRINT_TEST_NAME();

    line_ptr = &line;
    lp = offsetof(Line, data);

    value = decode_number();
    ASSERT_EQ(value, 0);

    value = decode_number();
    ASSERT_EQ(value, 256);

    value = decode_number();
    ASSERT_EQ(value, 769);
}

int main(void) {
    initialize_target();
    test_decode_byte();
    test_decode_number();
    return 0;
}