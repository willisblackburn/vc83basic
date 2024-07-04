#include "test.h"

void test_decode_byte(void) {
    char byte_value;
    const char line_data[] = {
        0x00, 0x01, 0x03
    };

    PRINT_TEST_NAME();

    set_line(0, line_data, sizeof line_data);

    byte_value = decode_byte();
    ASSERT_EQ(byte_value, 0x00);

    byte_value = decode_byte();
    ASSERT_EQ(byte_value, 0x01);

    byte_value = decode_byte();
    ASSERT_EQ(byte_value, 0x03);
}

void test_decode_number(void) {
    int value;
    const char line_data[] = {  TOKEN_NUM, 0, 0, TOKEN_NUM, 0, 1, TOKEN_NUM, 1, 3 };

    PRINT_TEST_NAME();

    set_line(0, line_data, sizeof line_data);

    value = decode_number();
    ASSERT_EQ(value, 0);

    value = decode_number();
    ASSERT_EQ(value, 256);

    value = decode_number();
    ASSERT_EQ(value, 769);
}

void test_decode_name(void) {
    const char line_data[] = {  'X' | NT_STOP, 'T', 'H', 'I', 'N', 'G', '3' | NT_STOP };

    PRINT_TEST_NAME();

    set_line(0, line_data, sizeof line_data);

    decode_name();
    ASSERT_EQ(name_ptr, line_buffer.data);
    ASSERT_EQ(name_length, 1);

    decode_name();
    ASSERT_EQ(name_ptr, line_buffer.data + 1);
    ASSERT_EQ(name_length, 6);
}

int main(void) {
    initialize_target();
    test_decode_byte();
    test_decode_number();
    test_decode_name();
    return 0;
}