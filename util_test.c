#include "test.h"

// test_data to use in tests
static char test_data[10000];

static void fill_test_data(size_t offset, size_t size) {
    size_t i;
    char* p = test_data + offset;
    for (i = 0; i < size; ++i) {
        *p++ = (char)i;
    }
}

static void verify_test_data(const char* p, size_t size) {
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

static void test_copy_down_case(size_t size, size_t offset) {
    memset(test_data, 0, sizeof test_data);
    // Set up test data in test_data + offset and try to copy it to the lower position.
    fill_test_data(offset, size);
    HEXDUMP(test_data + offset, 16);
    copy_down_ax(test_data, test_data + offset, size);
    HEXDUMP(test_data, 16);
    verify_test_data(test_data, size);
}

static void test_copy_down(void) {
    PRINT_TEST_NAME();

    test_copy_down_case(10, 1);
    test_copy_down_case(10, 100);
    test_copy_down_case(10, 256);
    test_copy_down_case(256, 1);
    test_copy_down_case(256, 100);
    test_copy_down_case(256, 256);
    test_copy_down_case(4000, 1);
    test_copy_down_case(4000, 100);
    test_copy_down_case(4000, 256);
}

static void test_copy_up_case(size_t size, size_t offset) {
    memset(test_data, 0, sizeof test_data);
    // Set up test data in test_data and try to copy it to the higher position.
    fill_test_data(0, size);
    HEXDUMP(test_data, 16);
    copy_up_ax(test_data + offset, test_data, size);
    HEXDUMP(test_data + offset, 16);
    verify_test_data(test_data + offset, size);
}

static void test_copy_up(void) {
    PRINT_TEST_NAME();

    test_copy_up_case(10, 1);
    test_copy_up_case(10, 100);
    test_copy_up_case(10, 256);
    test_copy_up_case(256, 1);
    test_copy_up_case(256, 100);
    test_copy_up_case(256, 256);
    test_copy_up_case(4000, 1);
    test_copy_up_case(4000, 100);
    test_copy_up_case(4000, 256);
}

static int f1(void) {
    return 31415;
}

static int f2(void) {
    return 7771;
}

static void test_invoke_indexed_vector(void) {
    int result;
    void* table[] = { (const char*)f1 - 1, (const char*)f2 - 1, (const char*)f2 - 1, (const char*)f1 - 1 };

    PRINT_TEST_NAME();

    result = invoke_indexed_vector(table, 0);
    ASSERT_EQ(result, 31415);
    result = invoke_indexed_vector(table, 1);
    ASSERT_EQ(result, 7771);
    result = invoke_indexed_vector(table, 2);
    ASSERT_EQ(result, 7771);
    result = invoke_indexed_vector(table, 3);
    ASSERT_EQ(result, 31415);
}

int main(void) {
    initialize_target();
    test_copy_down();
    test_copy_up();
    test_invoke_indexed_vector();
    return 0;
}