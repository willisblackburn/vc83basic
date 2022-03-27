#include "test.h"

static void test_encode_byte(void) {
    int err;

    PRINT_TEST_NAME();

    err = encode_byte(2, 0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(output_buffer[0], 2);
    ASSERT_EQ(w, 1);

    err = encode_byte(2, 1);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(output_buffer[1], 2);
    ASSERT_EQ(w, 2);

    err = encode_byte(255, 0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(output_buffer[0], 255);
    ASSERT_EQ(w, 1);

    // Encode at end of buffer should fail
    err = encode_number(100, 255);
    ASSERT_EQ(err, 1);
}

static void test_encode_number(void) {
    int err;

    PRINT_TEST_NAME();

    err = encode_number(0, 0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(output_buffer[0], 2);
    ASSERT_EQ(output_buffer[1], 0);
    ASSERT_EQ(output_buffer[2], 0);
    ASSERT_EQ(w, 3);

    err = encode_number(256, 0);
    ASSERT_EQ(err, 0);
    err = encode_number(1000, 3);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(output_buffer[0], 2);
    ASSERT_EQ(output_buffer[1], 0);
    ASSERT_EQ(output_buffer[2], 1);
    ASSERT_EQ(output_buffer[3], 2);
    ASSERT_EQ(output_buffer[4], 232);
    ASSERT_EQ(output_buffer[5], 3);
    ASSERT_EQ(w, 6);

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