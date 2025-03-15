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

void test_clear_memory(void) {
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

    // Passing size = 0 should clear 256 bytes
    fill_test_data(0, 258);
    clear_memory(test_data, 0);
    // Should clear offsets 0-255
    ASSERT_EQ(test_data[0], 0);
    ASSERT_EQ(test_data[255], 0);
    ASSERT_EQ(test_data[256], 0); // fill_test_data sets offset 256 to 0
    ASSERT_EQ(test_data[257], 1);
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

void test_mul2(void) {
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
    ASSERT_EQ(Y, 0);
    result = div10(1);
    ASSERT_EQ(result, 0);
    ASSERT_EQ(Y, 1);
    result = div10(10);
    ASSERT_EQ(result, 1);
    ASSERT_EQ(Y, 0);
    result = div10(399);
    ASSERT_EQ(result, 39);
    ASSERT_EQ(Y, 9);
    result = div10(10000);
    ASSERT_EQ(result, 1000);
    ASSERT_EQ(Y, 0);
}

int f1(void) {
    return 31415;
}

int f2(void) {
    return 7771;
}

void test_invoke_indexed_vector(void) {
    int result;
    void* table[] = { (char*)f1 - 1, (char*)f2 - 1, (char*)f2 - 1, (char*)f1 - 1 };

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

void test_read_number(void) {
    int number;

    PRINT_TEST_NAME();

    number = read_number("10 PRINT X", 0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(number, 10);
    ASSERT_EQ(Y, 2);

    // The function should honor the current read position.
    number = read_number("1020 PRINT X", 2);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(number, 20);
    ASSERT_EQ(Y, 4);

    // The function should return carry set if an invalid number.
    read_number("invalid", 0);
    ASSERT_NE(err, 0);
    ASSERT_EQ(Y, 0);

    read_number("", 0);
    ASSERT_NE(err, 0);
    ASSERT_EQ(Y, 0);
}

void call_format_number(int number, char set_buffer_pos) {
    buffer_pos = set_buffer_pos;
    format_number(number);
}

void test_format_number(void) {
    PRINT_TEST_NAME();

    call_format_number(5, 0);
    ASSERT_EQ(buffer[0], '5');
    ASSERT_EQ(buffer_pos, 1);

    call_format_number(10, 0);
    ASSERT_EQ(buffer[0], '1');
    ASSERT_EQ(buffer[1], '0');
    ASSERT_EQ(buffer_pos, 2);
    
    call_format_number(32767, 0);
    ASSERT_EQ(buffer[0], '3');
    ASSERT_EQ(buffer[1], '2');
    ASSERT_EQ(buffer[2], '7');
    ASSERT_EQ(buffer[3], '6');
    ASSERT_EQ(buffer[4], '7');
    ASSERT_EQ(buffer_pos, 5);
}

int main(void) {
    initialize_target();
    test_clear_memory();
    test_copy();
    test_reverse_copy();
    test_mul2();
    test_mul10();
    test_div10();
    test_invoke_indexed_vector();
    test_read_number();
    test_format_number();
    return 0;
}