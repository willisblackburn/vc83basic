#include "test.h"

static void test_encode_int(void) {
    int err;

    PRINT_TEST_NAME();

    w = 0;
    err = encode_int(0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(output_buffer[0], 2);
    ASSERT_EQ(output_buffer[1], 0);
    ASSERT_EQ(output_buffer[2], 0);
    ASSERT_EQ(w, 3);

    w = 0;
    err = encode_int(256);
    err = encode_int(1000);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(output_buffer[0], 2);
    ASSERT_EQ(output_buffer[1], 0);
    ASSERT_EQ(output_buffer[2], 1);
    ASSERT_EQ(output_buffer[3], 2);
    ASSERT_EQ(output_buffer[4], 232);
    ASSERT_EQ(output_buffer[5], 3);
    ASSERT_EQ(w, 6);
}

int main(void) {
    initialize_target();
    test_encode_int();
    return 0;
}