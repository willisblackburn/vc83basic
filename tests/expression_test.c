#include "test.h"

void test_stack_alloc_free(void) {
    char p;

    PRINT_TEST_NAME();

    initialize_program();

    ASSERT_EQ(osp, OP_STACK_SIZE);
    ASSERT_EQ(psp, PRIMARY_STACK_SIZE);

    p = stack_alloc(2);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(psp, PRIMARY_STACK_SIZE - 2);
    ASSERT_EQ(p, psp);

    p = stack_alloc(64);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(psp, PRIMARY_STACK_SIZE - 2 - 64);
    ASSERT_EQ(p, psp);

    stack_free(64);
    ASSERT_EQ(psp, PRIMARY_STACK_SIZE - 2);

    stack_free(2);
    ASSERT_EQ(psp, PRIMARY_STACK_SIZE);

    // Test overflow; no matter what PRIMARY_STACK_SIZE is, allocating 96 three times should overflow
    stack_alloc(96);
    stack_alloc(96);
    stack_alloc(96);
    ASSERT_NE(err, 0);
}

void set_name_ptr(const char* name) {
    // Parse given name to set name_ptr and high bit on final character.
    // Also sets name_length, which would normally be set in decode_name.
    strcpy(buffer, name);
    name_ptr = buffer;
    name_length = strlen(buffer);
    buffer[name_length - 1] |= NT_STOP;
}

void test_evaluate_expression(void) {
    int value;

    const char line_data_1[] = { TOKEN_NUM, 0x0A, 0x02, TOKEN_NO_VALUE };
    const char line_data_2[] = { 'X', 'Y' | NT_STOP, TOKEN_NO_VALUE };
    const char line_data_3[] = { 'D', 'A', 'T', 'A' | NT_STOP, TOKEN_NO_VALUE };

    PRINT_TEST_NAME();

    initialize_program();

    set_line(0, line_data_1, sizeof line_data_1);
    evaluate_expression();
    ASSERT_EQ(err, 0);
    value = pop_value();
    ASSERT_EQ(value, 522);

    set_line(0, line_data_2, sizeof line_data_2);
    evaluate_expression();
    ASSERT_EQ(err, 0);
    value = pop_value();
    ASSERT_EQ(value, 0);

    // Create a new variable and give it a value.

    set_name_ptr("DATA");
    find_name(variable_name_table_ptr);
    ASSERT_NE(err, 0);
    add_variable(2);
    ASSERT_EQ(err, 0);

    HEXDUMP(variable_name_table_ptr, 32);

    ASSERT_EQ(record_ptr, variable_name_table_ptr + 5 + 5);
    record_ptr[0] = 0x0A;
    record_ptr[1] = 0x01;

    set_line(0, line_data_3, sizeof line_data_3);
    evaluate_expression();
    ASSERT_EQ(err, 0);
    value = pop_value();
    ASSERT_EQ(value, 266);
}

void test_one_op(char op, int expected00, int expected01, int expected10, int expected11) {

    int result;
    char line_data[] = { TOKEN_NUM, 0x00, 0x00, 0, TOKEN_NUM, 0x00, 0x00, TOKEN_NO_VALUE };

    DEBUG(op);

    line_data[3] = TOKEN_OP | op;
    line_data[1] = 0;
    line_data[5] = 0;
    set_line(0, line_data, sizeof line_data);
    evaluate_expression();
    ASSERT_EQ(err, 0);
    result = pop_value();
    ASSERT_EQ(result, expected00);

    line_data[1] = 0;
    line_data[5] = 1;
    set_line(0, line_data, sizeof line_data);
    evaluate_expression();
    ASSERT_EQ(err, 0);
    result = pop_value();
    ASSERT_EQ(result, expected01);

    line_data[1] = 1;
    line_data[5] = 0;
    set_line(0, line_data, sizeof line_data);
    evaluate_expression();
    ASSERT_EQ(err, 0);
    result = pop_value();
    ASSERT_EQ(result, expected10);

    line_data[1] = 1;
    line_data[5] = 1;
    set_line(0, line_data, sizeof line_data);
    evaluate_expression();
    ASSERT_EQ(err, 0);
    result = pop_value();
    ASSERT_EQ(result, expected11);
}

void test_one_unary_op(char op, int expected0, int expected1) {

    int result;
    char line_data[] = { 0, TOKEN_NUM, 0x00, 0x00, TOKEN_NO_VALUE };

    DEBUG(op);

    line_data[0] = TOKEN_UNARY_OP | op;
    line_data[2] = 0;
    set_line(0, line_data, sizeof line_data);
    evaluate_expression();
    ASSERT_EQ(err, 0);
    result = pop_value();
    ASSERT_EQ(result, expected0);

    line_data[2] = 1;
    set_line(0, line_data, sizeof line_data);
    evaluate_expression();
    ASSERT_EQ(err, 0);
    result = pop_value();
    ASSERT_EQ(result, expected1);
}

void test_evaluate_expression_op(void) {

    PRINT_TEST_NAME();

    initialize_program();

    test_one_op(OP_ADD, 0, 1, 1, 2);
    test_one_op(OP_SUB, 0, -1, 1, 0);

    test_one_unary_op(UNARY_OP_MINUS, 0, -1);
}

void test_evaluate_expression_op_precedence(void) {

    int result;

    // 2-1-1 = 0
    char line_data_1[] = { TOKEN_NUM, 0x02, 0x00, TOKEN_OP | OP_SUB, 
        TOKEN_NUM, 0x01, 0x00, TOKEN_OP | OP_SUB, TOKEN_NUM, 0x01, 0x00, TOKEN_NO_VALUE };
    // 2-(1-1) = 2
    char line_data_2[] = { TOKEN_NUM, 0x02, 0x00, TOKEN_OP | OP_SUB, TOKEN_PAREN,
        TOKEN_NUM, 0x01, 0x00, TOKEN_OP | OP_SUB, TOKEN_NUM, 0x01, 0x00, TOKEN_NO_VALUE, TOKEN_NO_VALUE };

    PRINT_TEST_NAME();

    initialize_program();

    set_line(0, line_data_1, sizeof line_data_1);
    evaluate_expression();
    ASSERT_EQ(err, 0);
    result = pop_value();
    ASSERT_EQ(result, 0);

    set_line(0, line_data_2, sizeof line_data_2);
    evaluate_expression();
    ASSERT_EQ(err, 0);
    result = pop_value();
    ASSERT_EQ(result, 2);
}

int main(void) {
    initialize_target();
    test_stack_alloc_free();
    test_evaluate_expression();
    test_evaluate_expression_op();
    test_evaluate_expression_op_precedence();
    return 0;
}
