#include "test.h"

static void test_encode_byte(void) {
    int err;

    const char line_data_1[] = { 0x02 };
    const char line_data_2[] = { 0x02, 0x03 };
    const char line_data_3[] = { 0xFF };

    PRINT_TEST_NAME();

    lp = offsetof(Line, data);
    err = encode_byte(2);
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_1, sizeof line_data_1);
    ASSERT_EQ(lp, offsetof(Line, data) + sizeof line_data_1);

    err = encode_byte(3);
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_2, sizeof line_data_2);
    ASSERT_EQ(lp, offsetof(Line, data) + sizeof line_data_2);

    lp = offsetof(Line, data);
    err = encode_byte(255);
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_3, sizeof line_data_3);
    ASSERT_EQ(lp, offsetof(Line, data) + sizeof line_data_3);

    // Encode at end of buffer should fail
    lp = 255;
    err = encode_byte(100);
    ASSERT_NE(err, 0);
}

static void test_encode_number(void) {
    int err;

    const char line_data_1[] = { TOKEN_NUM, 0x00, 0x00, 0x00, 0x00, 0 };
    const char line_data_2[] = { TOKEN_NUM, 0x00, 0x00, 0x00, 0x48, 133,
        TOKEN_NUM, 0x00, 0x00, 0x80, 0x00, 139,
        TOKEN_NUM, 0x81, 0xCF, 0x0F, 0x49, 128 };

    PRINT_TEST_NAME();

    SET_FPX(FP0, POSITIVE, 1, 0);
    lp = offsetof(Line, data);
    err = encode_number();
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_1, sizeof line_data_1);
    ASSERT_EQ(lp, offsetof(Line, data) + sizeof line_data_1);

    // 100
    SET_FPX(FP0, POSITIVE, 133, 0xC8000000);
    lp = offsetof(Line, data);
    err = encode_number();
    ASSERT_EQ(err, 0);

    // 4112
    SET_FPX(FP0, POSITIVE, 139, 0x80800000);
    err = encode_number();
    ASSERT_EQ(err, 0);

    // 3.14159
    SET_FPX(FP0, POSITIVE, 128, 0xC90FCF81);
    err = encode_number();
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_2, sizeof line_data_2);
    ASSERT_EQ(lp, offsetof(Line, data) + sizeof line_data_2);

    // Encode at end of buffer should fail (doesn't matter what FP0 is)
    lp = 252;
    err = encode_number();
    ASSERT_NE(err, 0);
}

int main(void) {
    initialize_target();
    test_encode_byte();
    test_encode_number();
    return 0;
}