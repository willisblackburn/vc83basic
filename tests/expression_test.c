#include "test.h"

void set_decode_name_ptr(const char* name) {
    // Parse given name to set decode_name_ptr and high bit on final character.
    // Also sets decode_name_length, which would normally be set in decode_name.
    strcpy(buffer, name);
    decode_name_ptr = buffer;
    decode_name_length = strlen(buffer);
    buffer[decode_name_length - 1] |= NT_STOP;
}

void test_evaluate_expression(void) {
    int value;

    const char line_data_1[] = { '5', '2', '2', 0 };
    const char line_data_2[] = { 'X', 'Y' | NT_STOP };
    const char line_data_3[] = { 'D', 'A', 'T', 'A' | NT_STOP };

    PRINT_TEST_NAME();

    initialize_program();

    set_line(0, line_data_1, sizeof line_data_1);
    value = evaluate_expression();
    ASSERT_EQ(err, 0);
    ASSERT_EQ(value, 522);

    set_line(0, line_data_2, sizeof line_data_2);
    value = evaluate_expression();
    ASSERT_EQ(err, 0);
    ASSERT_EQ(value, 0);

    // Create a new variable and give it a value.

    set_decode_name_ptr("DATA");
    find_name(variable_name_table_ptr);
    ASSERT_NE(err, 0);
    add_variable(2);
    ASSERT_EQ(err, 0);

    HEXDUMP(variable_name_table_ptr, 32);

    ASSERT_EQ(name_ptr, variable_name_table_ptr + 5 + 5);
    name_ptr[0] = 0x0A;
    name_ptr[1] = 0x01;

    set_line(0, line_data_3, sizeof line_data_3);
    value = evaluate_expression();
    ASSERT_EQ(err, 0);
    ASSERT_EQ(value, 266);
}

int main(void) {
    initialize_target();
    test_evaluate_expression();
    return 0;
}
