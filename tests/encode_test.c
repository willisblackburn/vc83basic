#include "test.h"

void test_encode_byte(void) {

    const char line_data_1[] = { 0x02 };
    const char line_data_2[] = { 0x02, 0x03 };
    const char line_data_3[] = { 0xFF };

    PRINT_TEST_NAME();

    line_pos = offsetof(Line, data);
    encode_byte(2);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_1, sizeof line_data_1);
    ASSERT_EQ(line_pos, offsetof(Line, data) + sizeof line_data_1);

    encode_byte(3);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_2, sizeof line_data_2);
    ASSERT_EQ(line_pos, offsetof(Line, data) + sizeof line_data_2);

    line_pos = offsetof(Line, data);
    encode_byte(255);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_3, sizeof line_data_3);
    ASSERT_EQ(line_pos, offsetof(Line, data) + sizeof line_data_3);
}

int main(void) {
    initialize_target();
    test_encode_byte();
    return 0;
}