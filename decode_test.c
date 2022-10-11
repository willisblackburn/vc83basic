#include "test.h"

static void test_decode_byte(void) {
    char byte_value;
    const char line_data[] = { 0, 0, 1, 3 };

    PRINT_TEST_NAME();

    byte_value = decode_byte(line_data, 0);
    ASSERT_EQ(byte_value, 0);

    byte_value = decode_byte(line_data, 2);
    ASSERT_EQ(byte_value, 1);
}

static void test_decode_number(void) {
    int value;
    const char line_data_1[] = { TOKEN_NUM, 0, 0, TOKEN_NUM, 0, 1 };
    const char line_data_2[] = { TOKEN_NUM, 1, 3 };

    PRINT_TEST_NAME();

    value = decode_number(line_data_1, 0);
    ASSERT_EQ(value, 0);

    value = decode_number(line_data_1, 3);
    ASSERT_EQ(value, 256);

    value = decode_number(line_data_2, 0);
    ASSERT_EQ(value, 769);
}

int main(void) {
    initialize_target();
    test_decode_byte();
    test_decode_number();
    return 0;
}