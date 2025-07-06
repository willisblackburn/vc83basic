#include "test.h"

// test_data to use in tests
char test_data[10000];

void fill_test_data(size_t offset, size_t size) {
    size_t i;
    char* p = test_data + offset;
    for (i = 0; i < size; ++i) {
        *p++ = (char)i;
    }
}

void verify_test_data(const char* p, size_t size) {
    // Check first 4 and last 4 bytes.
    ASSERT_EQ(p[0], 0);
    ASSERT_EQ(p[1], 1);
    ASSERT_EQ(p[2], 2);
    ASSERT_EQ(p[3], 3);
    ASSERT_EQ(p[size - 4], (char)(size - 4));
    ASSERT_EQ(p[size - 3], (char)(size - 3));
    ASSERT_EQ(p[size - 2], (char)(size - 2));
    ASSERT_EQ(p[size - 1], (char)(size - 1));
}

void test_copy_case(size_t size, size_t offset, int line) {
    fprintf(stderr, "  %s:%d: test_copy_case(size=%u, offset=%u)\n", __FILE__, line, size, offset);
    memset(test_data, 0, sizeof test_data);
    // Set up test data in test_data + offset and try to copy it to the lower position.
    fill_test_data(offset, size);
    HEXDUMP(test_data + offset, 16);
    src_ptr = test_data + offset;
    dst_ptr = test_data;
    copy(size);
    HEXDUMP(test_data, 16);
    verify_test_data(test_data, size);
}

void test_copy(void) {
    PRINT_TEST_NAME();

    test_copy_case(10, 1, __LINE__);
    test_copy_case(10, 100, __LINE__);
    test_copy_case(10, 256, __LINE__);
    test_copy_case(256, 1, __LINE__);
    test_copy_case(256, 100, __LINE__);
    test_copy_case(256, 256, __LINE__);
    test_copy_case(4000, 1, __LINE__);
    test_copy_case(4000, 100, __LINE__);
    test_copy_case(4000, 256, __LINE__);
}

void test_reverse_copy_case(size_t size, size_t offset, int line) {
    fprintf(stderr, "  %s:%d: test_reverse_copy_case(size=%u, offset=%u)\n", __FILE__, line, size, offset);
    memset(test_data, 0, sizeof test_data);
    // Set up test data in test_data and try to copy it to the higher position.
    fill_test_data(0, size);
    HEXDUMP(test_data, 16);
    src_ptr = test_data;
    dst_ptr = test_data + offset;
    reverse_copy(size);
    HEXDUMP(test_data + offset, 16);
    verify_test_data(test_data + offset, size);
}

void test_reverse_copy(void) {
    PRINT_TEST_NAME();

    test_reverse_copy_case(10, 1, __LINE__);
    test_reverse_copy_case(10, 100, __LINE__);
    test_reverse_copy_case(10, 256, __LINE__);
    test_reverse_copy_case(256, 1, __LINE__);
    test_reverse_copy_case(256, 100, __LINE__);
    test_reverse_copy_case(256, 256, __LINE__);
    test_reverse_copy_case(4000, 1, __LINE__);
    test_reverse_copy_case(4000, 100, __LINE__);
    test_reverse_copy_case(4000, 256, __LINE__);
}

void test_mul10(void) {
    int result;

    PRINT_TEST_NAME();

    result = mul10(0);
    ASSERT_EQ(result, 0);
    result = mul10(1);
    ASSERT_EQ(result, 10);
    result = mul10(30);
    ASSERT_EQ(result, 300);
    result = mul10(1000);
    ASSERT_EQ(result, 10000);
}

void test_div10(void) {
    int result;

    PRINT_TEST_NAME();

    result = div10(0);
    ASSERT_EQ(result, 0);
    ASSERT_EQ(reg_y, 0);
    result = div10(1);
    ASSERT_EQ(result, 0);
    ASSERT_EQ(reg_y, 1);
    result = div10(10);
    ASSERT_EQ(result, 1);
    ASSERT_EQ(reg_y, 0);
    result = div10(399);
    ASSERT_EQ(result, 39);
    ASSERT_EQ(reg_y, 9);
    result = div10(10000);
    ASSERT_EQ(result, 1000);
    ASSERT_EQ(reg_y, 0);
}

int main(void) {
    initialize_target();
    test_copy();
    test_reverse_copy();
    test_mul10();
    test_div10();
    return 0;
}