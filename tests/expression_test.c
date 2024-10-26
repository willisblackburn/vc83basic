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

void set_match_ptr(const char* name) {
    // Parse given name to set match_ptr and high bit on final character.
    // Also sets match_length, which would normally be set in decode_name.
    strcpy(buffer, name);
    match_ptr = buffer;
    match_length = strlen(buffer);
    buffer[match_length - 1] |= NT_STOP;
}

void test_one_op(char op, const Float* expected00, const Float* expected01, const Float* expected10, 
                        const Float* expected11) {

    char line_data[] = { '0', 0, 0 /* op */, '0', 0, 0 };
    Float value;

    DEBUG(op);

    line_data[2] = TOKEN_OP | op;
    line_data[0] = '0';
    line_data[3] = '0';
    set_line(0, line_data, sizeof line_data);
    evaluate_expression();
    ASSERT_EQ(err, 0);
    pop_fp0();
    store_fpx(&FP0, &value);
    ASSERT_FLOAT_EQ(value, expected00->e, expected00->t);

    line_data[0] = '0';
    line_data[3] = '1';
    set_line(0, line_data, sizeof line_data);
    evaluate_expression();
    ASSERT_EQ(err, 0);
    store_fpx(&FP0, &value);
    ASSERT_FLOAT_EQ(value, expected01->e, expected01->t);

    line_data[0] = '1';
    line_data[3] = '0';
    set_line(0, line_data, sizeof line_data);
    evaluate_expression();
    ASSERT_EQ(err, 0);
    pop_fp0();
    store_fpx(&FP0, &value);
    ASSERT_FLOAT_EQ(value, expected10->e, expected10->t);

    line_data[0] = '1';
    line_data[3] = '1';
    set_line(0, line_data, sizeof line_data);
    evaluate_expression();
    ASSERT_EQ(err, 0);
    pop_fp0();
    store_fpx(&FP0, &value);
    ASSERT_FLOAT_EQ(value, expected11->e, expected11->t);
}

void test_one_unary_op(char op, const Float* expected0, const Float* expected1) {

    char line_data[] = { 0 /* op */, '0', 0, 0 };
    Float value;

    DEBUG(op);

    line_data[0] = TOKEN_UNARY_OP | op;
    line_data[1] = '0';
    set_line(0, line_data, sizeof line_data);
    evaluate_expression();
    ASSERT_EQ(err, 0);
    pop_fp0();
    store_fpx(&FP0, &value);
    ASSERT_FLOAT_EQ(value, expected0->e, expected0->t);

    line_data[1] = '1';
    set_line(0, line_data, sizeof line_data);
    evaluate_expression();
    ASSERT_EQ(err, 0);
    pop_fp0();
    store_fpx(&FP0, &value);
    ASSERT_FLOAT_EQ(value, expected1->e, expected1->t);
}

void test_evaluate_expression_op(void) {
    const Float value_0 = { 0x00000000, 0 };
    const Float value_negative_0 = { 0x80000000, 0 };
    const Float value_1 = { 0x00000000, 127 };
    const Float value_negative_1 = { 0x80000000, 127 };
    const Float value_2 = { 0x00000000, 128 };

    PRINT_TEST_NAME();

    initialize_program();

    test_one_op(OP_ADD, &value_0, &value_1, &value_1, &value_2);
    test_one_op(OP_SUB, &value_0, &value_negative_1, &value_1, &value_0);

    test_one_op(OP_EQ, &value_1, &value_0, &value_0, &value_1);
    test_one_op(OP_NE, &value_0, &value_1, &value_1, &value_0);
    test_one_op(OP_LT, &value_0, &value_1, &value_0, &value_0);
    test_one_op(OP_LE, &value_1, &value_1, &value_0, &value_1);
    test_one_op(OP_GT, &value_0, &value_0, &value_1, &value_0);
    test_one_op(OP_GE, &value_1, &value_0, &value_1, &value_1);

    test_one_op(OP_AND, &value_0, &value_0, &value_0, &value_1);
    test_one_op(OP_OR, &value_0, &value_1, &value_1, &value_1);

    test_one_unary_op(UNARY_OP_MINUS, &value_negative_0, &value_negative_1);
    test_one_unary_op(UNARY_OP_NOT, &value_1, &value_0);
}

void test_evaluate_expression_op_precedence(void) {
    Float value;

    // 2-1-1 = 0
    char line_data_1[] = { '2', 0, TOKEN_OP | OP_SUB, '1', 0, TOKEN_OP | OP_SUB, '1', 0, 0 };
    // 2-(1-1) = 2
    char line_data_2[] = { '2', 0, TOKEN_OP | OP_SUB, '(', '1', 0, TOKEN_OP | OP_SUB, '1', 0, 0, 0 };

    PRINT_TEST_NAME();

    initialize_program();

    set_line(0, line_data_1, sizeof line_data_1);
    evaluate_expression();
    ASSERT_EQ(err, 0);
    pop_fp0();
    store_fpx(&FP0, &value);
    ASSERT_FLOAT_EQ(value, 0, 0x00000000);

    set_line(0, line_data_2, sizeof line_data_2);
    evaluate_expression();
    ASSERT_EQ(err, 0);
    pop_fp0();
    store_fpx(&FP0, &value);
    ASSERT_FLOAT_EQ(value, 128, 0x00000000);
}

int main(void) {
    initialize_target();
    test_stack_alloc_free();
    test_evaluate_expression_op();
    test_evaluate_expression_op_precedence();
    return 0;
}
