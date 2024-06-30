#include "test.h"

void test_evaluate_expression(void) {
    int value;

    const char line_data_1[] = { TOKEN_NUM, 0x0A, 0x02 };
    const char line_data_2[] = { TOKEN_VAR | 2, 'X', 'Y' };
    const char line_data_3[] = { TOKEN_VAR | 4, 'D', 'A', 'T', 'A' };

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

    name_ptr = "DATA";
    name_length = 4;
    find_name(variable_name_table_ptr);
    ASSERT_NE(err, 0);
    add_variable(2);
    ASSERT_EQ(err, 0);

    HEXDUMP(variable_name_table_ptr, 32);

    ASSERT_EQ(record_ptr, variable_name_table_ptr + 5 + 5);
    record_ptr[0] = 0x0A;
    record_ptr[1] = 0x01;

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
