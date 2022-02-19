#include "test.h"

// Buffer to use in tests
char buffer[10000];

void memcpy_lower(char* to, const char* from, size_t size);
void memcpy_higher(char* to, const char* from, size_t size);

void fill_test_data(char* p, size_t size) {
    size_t i;
    for (i = 0; i < size; ++i) {
        p[i] = (char)i;
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

void test_memcpy_lower_case(size_t size, size_t offset) {
    memset(buffer, 0, sizeof buffer);
    // Set up test data in buffer + offset and try to copy it to the lower position.
    fill_test_data(buffer + offset, size);
    HEXDUMP(buffer + offset, 16);
    memcpy_lower(buffer, buffer + offset, size);
    HEXDUMP(buffer, 16);
    verify_test_data(buffer, size);
}

void test_memcpy_lower(void) {
    PRINT_TEST_NAME();

    test_memcpy_lower_case(10, 1);
    test_memcpy_lower_case(10, 100);
    test_memcpy_lower_case(10, 256);
    test_memcpy_lower_case(256, 1);
    test_memcpy_lower_case(256, 100);
    test_memcpy_lower_case(256, 256);
    test_memcpy_lower_case(4000, 1);
    test_memcpy_lower_case(4000, 100);
    test_memcpy_lower_case(4000, 256);
}

void test_memcpy_higher_case(size_t size, size_t offset) {
    memset(buffer, 0, sizeof buffer);
    // Set up test data in buffer and try to copy it to the higher position.
    fill_test_data(buffer, size);
    HEXDUMP(buffer, 16);
    memcpy_higher(buffer + offset, buffer, size);
    HEXDUMP(buffer + offset, 16);
    verify_test_data(buffer + offset, size);
}

void test_memcpy_higher(void) {
    PRINT_TEST_NAME();

    test_memcpy_higher_case(10, 1);
    test_memcpy_higher_case(10, 100);
    test_memcpy_higher_case(10, 256);
    test_memcpy_higher_case(256, 1);
    test_memcpy_higher_case(256, 100);
    test_memcpy_higher_case(256, 256);
    test_memcpy_higher_case(4000, 1);
    test_memcpy_higher_case(4000, 100);
    test_memcpy_higher_case(4000, 256);
}

int main(void) {
    test_memcpy_lower();
    test_memcpy_higher();
    return 0;
}