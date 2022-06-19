#include "test.h"

static void test_encode_byte(void) {
    int err;

    PRINT_TEST_NAME();

    err = encode_byte(2, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_EQ(line_buffer.data[0], 2);
    ASSERT_EQ(w, offsetof(Line, data) + 1);

    err = encode_byte(2, offsetof(Line, data) + 1);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(line_buffer.data[1], 2);
    ASSERT_EQ(w, offsetof(Line, data) + 2);

    err = encode_byte(255, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_EQ(line_buffer.data[0], 255);
    ASSERT_EQ(w, offsetof(Line, data) + 1);

    // Encode at end of buffer should fail
    err = encode_number(100, 255);
    ASSERT_EQ(err, 1);
}

static void test_encode_number(void) {
    int err;

    PRINT_TEST_NAME();

    err = encode_number(0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_EQ(line_buffer.data[0], 2);
    ASSERT_EQ(line_buffer.data[1], 0);
    ASSERT_EQ(line_buffer.data[2], 0);
    ASSERT_EQ(w, offsetof(Line, data) + 3);

    err = encode_number(256, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    err = encode_number(1000, offsetof(Line, data) + 3);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(line_buffer.data[0], 2);
    ASSERT_EQ(line_buffer.data[1], 0);
    ASSERT_EQ(line_buffer.data[2], 1);
    ASSERT_EQ(line_buffer.data[3], 2);
    ASSERT_EQ(line_buffer.data[4], 232);
    ASSERT_EQ(line_buffer.data[5], 3);
    ASSERT_EQ(w, offsetof(Line, data) + 6);

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