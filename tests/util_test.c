/*
 * SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
 *
 * SPDX-License-Identifier: MIT
 */

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

int main(void) {
    initialize_target();
    test_clear_memory();
    test_copy();
    test_reverse_copy();
    test_invoke_indexed_vector();
    return 0;
}