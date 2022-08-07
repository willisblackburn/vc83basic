#include "test.h"

static void test_encode_byte(void) {
    int err;

    const char line_data_1[] = { 0x02 };
    const char line_data_2[] = { 0xFF };

    PRINT_TEST_NAME();

    err = encode_byte(2, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_1, sizeof line_data_1);
    ASSERT_EQ(lp, offsetof(Line, data) + sizeof line_data_1);

    err = encode_byte(2, offsetof(Line, data) + 1);
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data + 1, line_data_1, sizeof line_data_1);
    ASSERT_EQ(lp, offsetof(Line, data) + sizeof line_data_1 + 1);

    err = encode_byte(255, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_2, sizeof line_data_2);
    ASSERT_EQ(lp, offsetof(Line, data) + sizeof line_data_2);

    // Encode at end of buffer should fail
    err = encode_number(100, 255);
    ASSERT_EQ(err, 1);
}

static void test_encode_number(void) {
    int err;

    const char line_data_1[] = { TOKEN_INT, 0x00, 0x00 };
    const char line_data_2[] = { TOKEN_INT, 0x00, 0x01, TOKEN_INT, 0xE8, 0x03 };

    PRINT_TEST_NAME();

    err = encode_number(0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_1, sizeof line_data_1);
    ASSERT_EQ(lp, offsetof(Line, data) + sizeof line_data_1);

    err = encode_number(256, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    err = encode_number(1000, offsetof(Line, data) + 3);
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_2, sizeof line_data_2);
    ASSERT_EQ(lp, offsetof(Line, data) + sizeof line_data_2);

    // Encode at end of buffer should fail
    err = encode_number(100, 253);
    ASSERT_EQ(err, 1);
}

int main(void) {
    initialize_target();
    test_encode_byte();
    test_encode_number();
    return 0;
}