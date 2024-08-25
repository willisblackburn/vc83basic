#include "test.h"

void call_parse_name(const char* name) {
    // Parse given name to set name_ptr and high bit on final character.
    // Also sets name_length, which would normally be set in decode_name.
    strcpy(buffer, name);
    buffer_pos = 0;
    line_pos = 0;
    parse_name();
    ASSERT_EQ(err, 0);
    name_length = strlen(name);
}

void test_evaluate_expression(void) {
    int value;

    const char line_data_1[] = { TOKEN_NUM, 0x0A, 0x02 };
    const char line_data_2[] = { 'X', 'Y' | NT_STOP };
    const char line_data_3[] = { 'D', 'A', 'T', 'A' | NT_STOP };

    PRINT_TEST_NAME();

    set_line(0, line_data_1, sizeof line_data_1);
    value = evaluate_expression();
    ASSERT_EQ(err, 0);
    ASSERT_EQ(value, 522);

    set_line(0, line_data_2, sizeof line_data_2);
    value = evaluate_expression();
    ASSERT_EQ(err, 0);
    ASSERT_EQ(value, 0);

    // Create a new variable and give it a value.

    call_parse_name("DATA");
    find_name(variable_name_table_ptr);
    ASSERT_NE(err, 0);
    add_variable(2);
    ASSERT_EQ(err, 0);

    HEXDUMP(variable_name_table_ptr, 32);

    ASSERT_EQ(node_ptr, variable_name_table_ptr + 5 + 5);
    node_ptr[0] = 0x0A;
    node_ptr[1] = 0x01;

    set_line(0, line_data_3, sizeof line_data_3);
    value = evaluate_expression();
    ASSERT_EQ(err, 0);
    ASSERT_EQ(value, 266);
}

int main(void) {
    initialize_target();
    initialize_program();
    test_evaluate_expression();
    return 0;
}
