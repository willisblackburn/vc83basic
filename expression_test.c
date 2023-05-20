#include "test.h"

static void test_stack_alloc_free(void) {
    char p;

    PRINT_TEST_NAME();

    ASSERT_EQ(osp, OP_STACK_SIZE);
    ASSERT_EQ(psp, PRIMARY_STACK_SIZE);

    p = stack_alloc(2);
    ASSERT_EQ(carry_flag, 0);
    ASSERT_EQ(psp, PRIMARY_STACK_SIZE - 2);
    ASSERT_EQ(p, psp);

    p = stack_alloc(64);
    ASSERT_EQ(carry_flag, 0);
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
    ASSERT_NE(carry_flag, 0);

    // Re-initialize program since this test leaves it in a bad state.
    initialize_program();
}

static void test_one_op(char op, const Float* expected00, const Float* expected01, const Float* expected10, 
                        const Float* expected11) {
    char err;
    char line_data[] = {
            TOKEN_NUM, 0x00, 0x00, 0x00, 0x00, 0,   // 0-5
            0,                                      // 6  
            TOKEN_NUM, 0x00, 0x00, 0x00, 0x00, 0,   // 7-12
            TOKEN_NO_VALUE
        };
    const Float value_0 = { 0x00000000, 0 };
    const Float value_1 = { 0x00000000, 127 };
    Float value;

    DEBUG(op);

    line_data[6] = TOKEN_OP | op;

    // Set the exponent of each operand to either 0 (for value 0) or 127 (for value 1).

    memcpy(line_data + 1, &value_0, sizeof (Float));
    memcpy(line_data + 8, &value_0, sizeof (Float));
    set_line(0, line_data, sizeof line_data);
    err = evaluate_expression();
    ASSERT_EQ(err, 0);
    pop_fp0();
    store_fpx(&FP0, &value);
    ASSERT_FLOAT_EQ(value, expected00->e, expected00->t);

    memcpy(line_data + 1, &value_0, sizeof (Float));
    memcpy(line_data + 8, &value_1, sizeof (Float));
    set_line(0, line_data, sizeof line_data);
    err = evaluate_expression();
    ASSERT_EQ(err, 0);
    store_fpx(&FP0, &value);
    ASSERT_FLOAT_EQ(value, expected01->e, expected01->t);

    memcpy(line_data + 1, &value_1, sizeof (Float));
    memcpy(line_data + 8, &value_0, sizeof (Float));
    set_line(0, line_data, sizeof line_data);
    err = evaluate_expression();
    ASSERT_EQ(err, 0);
    pop_fp0();
    store_fpx(&FP0, &value);
    ASSERT_FLOAT_EQ(value, expected10->e, expected10->t);

    memcpy(line_data + 1, &value_1, sizeof (Float));
    memcpy(line_data + 8, &value_1, sizeof (Float));
    set_line(0, line_data, sizeof line_data);
    err = evaluate_expression();
    ASSERT_EQ(err, 0);
    pop_fp0();
    store_fpx(&FP0, &value);
    ASSERT_FLOAT_EQ(value, expected11->e, expected11->t);
}

static void test_one_unary_op(char op, const Float* expected0, const Float* expected1) {
    char err;
    char line_data[] = {
            0,                                          // 0        
            TOKEN_NUM, 0x00, 0x00, 0x00, 0x00, 0x00,    // 1-7
            TOKEN_NO_VALUE
        };
    const Float value_0 = { 0x00000000, 0 };
    const Float value_1 = { 0x00000000, 127 };
    Float value;

    DEBUG(op);

    line_data[0] = TOKEN_UNARY_OP | op;

    memcpy(line_data + 2, &value_0, sizeof (Float));
    set_line(0, line_data, sizeof line_data);
    err = evaluate_expression();
    ASSERT_EQ(err, 0);
    pop_fp0();
    store_fpx(&FP0, &value);
    ASSERT_FLOAT_EQ(value, expected0->e, expected0->t);

    memcpy(line_data + 2, &value_1, sizeof (Float));
    set_line(0, line_data, sizeof line_data);
    err = evaluate_expression();
    ASSERT_EQ(err, 0);
    pop_fp0();
    store_fpx(&FP0, &value);
    ASSERT_FLOAT_EQ(value, expected1->e, expected1->t);
}

static void test_evaluate_expression(void) {
    const Float value_0 = { 0x00000000, 0 };
    const Float value_negative_0 = { 0x80000000, 0 };
    const Float value_1 = { 0x00000000, 127 };
    const Float value_negative_1 = { 0x80000000, 127 };
    const Float value_2 = { 0x00000000, 128 };

    PRINT_TEST_NAME();

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

static void test_evaluate_expression_precedence(void) {
    char err;
    const Float value_0 = { 0x00000000, 0 };
    const Float value_1 = { 0x00000000, 127 };
    Float value;

    // 0 AND 0 = 0
    // Equals is higher precedence so result is 0
    char line_data_1[] = { TOKEN_NUM, 0x00, 0x00, 0x00, 0x00, 0x00, TOKEN_OP | OP_AND, 
        TOKEN_NUM, 0x00, 0x00, 0x00, 0x00, 0x00, TOKEN_OP | OP_EQ,
        TOKEN_NUM, 0x00, 0x00, 0x00, 0x00, 0x00, TOKEN_NO_VALUE };
    // (0 AND 0) = 0
    // Parens make it into 0 = 0 so result is 1
    char line_data_2[] = { TOKEN_PAREN, TOKEN_NUM, 0x00, 0x00, 0x00, 0x00, 0x00, TOKEN_OP | OP_AND, 
        TOKEN_NUM, 0x00, 0x00, 0x00, 0x00, 0x00, TOKEN_NO_VALUE, TOKEN_OP | OP_EQ,
        TOKEN_NUM, 0x00, 0x00, 0x00, 0x00, 0x00, TOKEN_NO_VALUE };

    PRINT_TEST_NAME();

    set_line(0, line_data_1, sizeof line_data_1);
    err = evaluate_expression();
    ASSERT_EQ(err, 0);
    pop_fp0();
    store_fpx(&FP0, &value);
    ASSERT_FLOAT_EQ(value, 0, 0x00000000);

    set_line(0, line_data_2, sizeof line_data_2);
    err = evaluate_expression();
    ASSERT_EQ(err, 0);
    pop_fp0();
    store_fpx(&FP0, &value);
    ASSERT_FLOAT_EQ(value, 127, 0x00000000);
}

int main(void) {
    initialize_target();
    initialize_program();
    test_stack_alloc_free();
    test_evaluate_expression();
    test_evaluate_expression_precedence();
    return 0;
}
