#include "test.h"

static void test_stack_alloc_free(void) {
    char err;

    PRINT_TEST_NAME();

    ASSERT_EQ(osp, OP_STACK_SIZE);
    ASSERT_EQ(psp, PRIMARY_STACK_SIZE);

    err = stack_alloc(2);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(psp, PRIMARY_STACK_SIZE - 2);
    ASSERT_EQ(reg_a, psp);
    ASSERT_EQ(reg_x, psp);

    err = stack_alloc(64);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(psp, PRIMARY_STACK_SIZE - 2 - 64);
    ASSERT_EQ(reg_a, psp);
    ASSERT_EQ(reg_x, psp);

    stack_free(64);
    ASSERT_EQ(psp, PRIMARY_STACK_SIZE - 2);

    stack_free(2);
    ASSERT_EQ(psp, PRIMARY_STACK_SIZE);

    // Test overflow; no matter what PRIMARY_STACK_SIZE is, allocating 96 three times should overflow
    stack_alloc(96);
    stack_alloc(96);
    err = stack_alloc(96);
    ASSERT_NE(err, 0);

    // Re-initialize program since this test leaves it in a bad state.
    initialize_program();
}

static void set_line(const char* data, size_t length) {
    line_buffer.number = 0;
    line_buffer.next_line_offset = (char)(length + offsetof(Line, data));
    memcpy(line_buffer.data, data, length);
    line_ptr = &line_buffer;
    lp = (char)offsetof(Line, data);
}

static void test_one_op(char op, long expected00, long expected01, long expected10, long expected11) {
    char err;
    char line_data[] = {
            TOKEN_NUM, 0x00, 0x00, 0x00, 0x00, 0x00,    // 0-5
            0,                                          // 6  
            TOKEN_NUM, 0x00, 0x00, 0x00, 0x00, 0x00,    // 7-12
            TOKEN_NO_VALUE
        };

    DEBUG(op);

    line_data[6] = TOKEN_OP | op;
    line_data[2] = 0;
    line_data[9] = 0;
    set_line(line_data, sizeof line_data);
    err = evaluate_expression();
    ASSERT_EQ(err, 0);
    pop_fp0();
    ASSERT_FLOAT_EQ(reg_fpa, 0, expected00);

    line_data[2] = 0;
    line_data[9] = 1;
    set_line(line_data, sizeof line_data);
    err = evaluate_expression();
    ASSERT_EQ(err, 0);
    pop_fp0();
    ASSERT_FLOAT_EQ(reg_fpa, 0, expected01);

    line_data[2] = 1;
    line_data[9] = 0;
    set_line(line_data, sizeof line_data);
    err = evaluate_expression();
    ASSERT_EQ(err, 0);
    pop_fp0();
    ASSERT_FLOAT_EQ(reg_fpa, 0, expected10);

    line_data[2] = 1;
    line_data[9] = 1;
    set_line(line_data, sizeof line_data);
    err = evaluate_expression();
    ASSERT_EQ(err, 0);
    pop_fp0();
    ASSERT_FLOAT_EQ(reg_fpa, 0, expected11);
}

static void test_one_unary_op(char op, int expected0, int expected1) {
    char err;
    char line_data[] = {
            0,                                          // 0        
            TOKEN_NUM, 0x00, 0x00, 0x00, 0x00, 0x00,    // 1-7
            TOKEN_NO_VALUE
        };

    DEBUG(op);

    line_data[0] = TOKEN_UNARY_OP | op;
    line_data[3] = 0;
    set_line(line_data, sizeof line_data);
    err = evaluate_expression();
    ASSERT_EQ(err, 0);
    pop_fp0();
    ASSERT_FLOAT_EQ(reg_fpa, 0, expected0);

    line_data[3] = 1;
    set_line(line_data, sizeof line_data);
    err = evaluate_expression();
    ASSERT_EQ(err, 0);
    pop_fp0();
    ASSERT_FLOAT_EQ(reg_fpa, 0, expected1);
}

static void test_evaluate_expression(void) {

    PRINT_TEST_NAME();

    test_one_op(OP_ADD, 0, 1, 1, 2);
    test_one_op(OP_SUB, 0, -1, 1, 0);

    test_one_op(OP_EQ, 1, 0, 0, 1);
    test_one_op(OP_NE, 0, 1, 1, 0);
    test_one_op(OP_LT, 0, 1, 0, 0);
    test_one_op(OP_LE, 1, 1, 0, 1);
    test_one_op(OP_GT, 0, 0, 1, 0);
    test_one_op(OP_GE, 1, 0, 1, 1);

    test_one_op(OP_AND, 0, 0, 0, 1);
    test_one_op(OP_OR, 0, 1, 1, 1);

    test_one_unary_op(UNARY_OP_MINUS, 0, -1);
    test_one_unary_op(UNARY_OP_NOT, 1, 0);
}

static void test_evaluate_expression_precedence(void) {
    char err;

    // 0 AND 0 = 0
    char line_data_1[] = { TOKEN_NUM, 0x00, 0x00, 0x00, 0x00, 0x00, TOKEN_OP | OP_AND, 
        TOKEN_NUM, 0x00, 0x00, 0x00, 0x00, 0x00, TOKEN_OP | OP_EQ,
        TOKEN_NUM, 0x00, 0x00, 0x00, 0x00, 0x00, TOKEN_NO_VALUE };
    // (0 AND 0) = 0
    char line_data_2[] = { TOKEN_PAREN, TOKEN_NUM, 0x00, 0x00, 0x00, 0x00, 0x00, TOKEN_OP | OP_AND, 
        TOKEN_NUM, 0x00, 0x00, 0x00, 0x00, 0x00, TOKEN_NO_VALUE, TOKEN_OP | OP_EQ,
        TOKEN_NUM, 0x00, 0x00, 0x00, 0x00, 0x00, TOKEN_NO_VALUE };

    PRINT_TEST_NAME();

    set_line(line_data_1, sizeof line_data_1);
    err = evaluate_expression();
    ASSERT_EQ(err, 0);
    pop_fp0();
    ASSERT_FLOAT_EQ(reg_fpa, 0, 0);

    set_line(line_data_2, sizeof line_data_2);
    err = evaluate_expression();
    ASSERT_EQ(err, 0);
    pop_fp0();
    ASSERT_FLOAT_EQ(reg_fpa, 0, 1);
}

int main(void) {
    initialize_target();
    initialize_program();
    test_stack_alloc_free();
    test_evaluate_expression();
    test_evaluate_expression_precedence();
    return 0;
}
