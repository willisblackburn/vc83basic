#include "test.h"

static void test_encode_byte(void) {

    const char line_data_1[] = { 0x02 };
    const char line_data_2[] = { 0x02, 0x03 };
    const char line_data_3[] = { 0xFF };

    PRINT_TEST_NAME();

    lp = offsetof(Line, data);
    encode_byte(2);
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_1, sizeof line_data_1);
    ASSERT_EQ(lp, offsetof(Line, data) + sizeof line_data_1);

    encode_byte(3);
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_2, sizeof line_data_2);
    ASSERT_EQ(lp, offsetof(Line, data) + sizeof line_data_2);

    lp = offsetof(Line, data);
    encode_byte(255);
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_3, sizeof line_data_3);
    ASSERT_EQ(lp, offsetof(Line, data) + sizeof line_data_3);

    // Encode at end of buffer should fail
    lp = 255;
    encode_byte(100);
    ASSERT_NE(err, 0);
}

static void test_encode_number(void) {

    const char line_data_1[] = { TOKEN_NUM, 0x00, 0x00 };
    const char line_data_2[] = { TOKEN_NUM, 0x00, 0x01, TOKEN_NUM, 0xE8, 0x03 };

    PRINT_TEST_NAME();

    lp = offsetof(Line, data);
    encode_number(0);
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_1, sizeof line_data_1);
    ASSERT_EQ(lp, offsetof(Line, data) + sizeof line_data_1);

    lp = offsetof(Line, data);
    encode_number(256);
    ASSERT_EQ(err, 0);
    encode_number(1000);
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_2, sizeof line_data_2);
    ASSERT_EQ(lp, offsetof(Line, data) + sizeof line_data_2);

    // Encode at end of buffer should fail
    lp = 253;
    encode_number(100);
    ASSERT_NE(err, 0);
}

int main(void) {
    initialize_target();
    test_encode_byte();
    test_encode_number();
    return 0;
}