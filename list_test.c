#include "test.h"

static void test_decode_number(void) {
    int value;
    const char line_data[] = { 0, 0, 1, 3 };

    PRINT_TEST_NAME();

    value = decode_number(line_data, 0);
    ASSERT_EQ(value, 0);

    value = decode_number(line_data, 1);
    ASSERT_EQ(value, 256);

    value = decode_number(line_data, 2);
    ASSERT_EQ(value, 769);
}

int main(void) {
    initialize_target();
    test_decode_number();
    return 0;
}