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

static void test_clear_memory(void) {
    PRINT_TEST_NAME();

    // Clear <256 bytes
    fill_test_data(0, 100);
    HEXDUMP(test_data, 16);
    clear_memory(test_data, 10);
    HEXDUMP(test_data, 16);
    // Should clear offsets 0-9, offset 10 remains the same.
    ASSERT_EQ(test_data[0], 0);
    ASSERT_EQ(test_data[9], 0);
    ASSERT_EQ(test_data[10], 10);

    // Clear >256 bytes
    fill_test_data(0, 300);
    clear_memory(test_data, 259);
    // Should clear offsets 0-9, offset 10 remains the same.
    ASSERT_EQ(test_data[0], 0);
    ASSERT_EQ(test_data[258], 0);
    ASSERT_EQ(test_data[259], 3);

    // Clear even multiple of 256 bytes
    fill_test_data(0, 1000);
    clear_memory(test_data, 512);
    // Should clear offsets 0-9, offset 10 remains the same.
    ASSERT_EQ(test_data[0], 0);
    ASSERT_EQ(test_data[511], 0);
    ASSERT_EQ(test_data[512], 0);
    ASSERT_EQ(test_data[513], 1);

    // Clear zero bytes
    test_data[0] = test_data[1] = 1;
    clear_memory(test_data, 0);
    ASSERT_EQ(test_data[0], 1);
    ASSERT_EQ(test_data[1], 1);
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

static void test_copy_bytes_case(size_t size, size_t offset) {
    memset(test_data, 0, sizeof test_data);
    // Set up test data in test_data + offset and try to copy it to the lower position.
    fill_test_data(offset, size);
    HEXDUMP(test_data + offset, 16);
    copy_bytes(test_data, test_data + offset, size);
    HEXDUMP(test_data, 16);
    verify_test_data(test_data, size);
}

static void test_copy_bytes(void) {
    PRINT_TEST_NAME();

    test_copy_bytes_case(10, 1);
    test_copy_bytes_case(10, 100);
    test_copy_bytes_case(10, 256);
    test_copy_bytes_case(256, 1);
    test_copy_bytes_case(256, 100);
    test_copy_bytes_case(256, 256);
    test_copy_bytes_case(4000, 1);
    test_copy_bytes_case(4000, 100);
    test_copy_bytes_case(4000, 256);
}

static void test_copy_bytes_back_case(size_t size, size_t offset) {
    memset(test_data, 0, sizeof test_data);
    // Set up test data in test_data and try to copy it to the higher position.
    fill_test_data(0, size);
    HEXDUMP(test_data, 16);
    copy_bytes_back(test_data + offset, test_data, size);
    HEXDUMP(test_data + offset, 16);
    verify_test_data(test_data + offset, size);
}

static void test_copy_bytes_back(void) {
    PRINT_TEST_NAME();

    test_copy_bytes_back_case(10, 1);
    test_copy_bytes_back_case(10, 100);
    test_copy_bytes_back_case(10, 256);
    test_copy_bytes_back_case(256, 1);
    test_copy_bytes_back_case(256, 100);
    test_copy_bytes_back_case(256, 256);
    test_copy_bytes_back_case(4000, 1);
    test_copy_bytes_back_case(4000, 100);
    test_copy_bytes_back_case(4000, 256);
}

static void test_mul2(void) {
    int result;

    PRINT_TEST_NAME();

    result = mul2(0);
    ASSERT_EQ(result, 0);
    result = mul2(1);
    ASSERT_EQ(result, 2);
    result = mul2(30);
    ASSERT_EQ(result, 60);
    result = mul2(1000);
    ASSERT_EQ(result, 2000);
}

static void test_mul10(void) {
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

static void test_div10(void) {
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

static int f1(void) {
    return 31415;
}

static int f2(void) {
    return 7771;
}

static void test_invoke_indexed_vector(void) {
    int result;
    void* table[] = { f1, f2, f2, f1 };

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

static void test_format_number(void) {
    PRINT_TEST_NAME();

    format_number(5, 0);
    ASSERT_EQ(buffer[0], '5');
    ASSERT_EQ(bp, 1);

    format_number(10, 0);
    ASSERT_EQ(buffer[0], '1');
    ASSERT_EQ(buffer[1], '0');
    ASSERT_EQ(bp, 2);
    
    format_number(32767, 0);
    ASSERT_EQ(buffer[0], '3');
    ASSERT_EQ(buffer[1], '2');
    ASSERT_EQ(buffer[2], '7');
    ASSERT_EQ(buffer[3], '6');
    ASSERT_EQ(buffer[4], '7');
    ASSERT_EQ(bp, 5);
}

int main(void) {
    initialize_target();
    test_clear_memory();
    test_copy_bytes();
    test_copy_bytes_back();
    test_mul2();
    test_mul10();
    test_div10();
    test_invoke_indexed_vector();
    test_format_number();
    return 0;
}