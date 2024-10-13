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
    evaluate_expression();
    ASSERT_EQ(err, 0);
    pop_fp0();
    store_fpx(&FP0, &value);
    ASSERT_FLOAT_EQ(value, expected00->e, expected00->t);

    memcpy(line_data + 1, &value_0, sizeof (Float));
    memcpy(line_data + 8, &value_1, sizeof (Float));
    set_line(0, line_data, sizeof line_data);
    evaluate_expression();
    ASSERT_EQ(err, 0);
    store_fpx(&FP0, &value);
    ASSERT_FLOAT_EQ(value, expected01->e, expected01->t);

    memcpy(line_data + 1, &value_1, sizeof (Float));
    memcpy(line_data + 8, &value_0, sizeof (Float));
    set_line(0, line_data, sizeof line_data);
    evaluate_expression();
    ASSERT_EQ(err, 0);
    pop_fp0();
    store_fpx(&FP0, &value);
    ASSERT_FLOAT_EQ(value, expected10->e, expected10->t);

    memcpy(line_data + 1, &value_1, sizeof (Float));
    memcpy(line_data + 8, &value_1, sizeof (Float));
    set_line(0, line_data, sizeof line_data);
    evaluate_expression();
    ASSERT_EQ(err, 0);
    pop_fp0();
    store_fpx(&FP0, &value);
    ASSERT_FLOAT_EQ(value, expected11->e, expected11->t);
}

void test_one_unary_op(char op, const Float* expected0, const Float* expected1) {

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
    evaluate_expression();
    ASSERT_EQ(err, 0);
    pop_fp0();
    store_fpx(&FP0, &value);
    ASSERT_FLOAT_EQ(value, expected0->e, expected0->t);

    memcpy(line_data + 2, &value_1, sizeof (Float));
    set_line(0, line_data, sizeof line_data);
    evaluate_expression();
    ASSERT_EQ(err, 0);
    pop_fp0();
    store_fpx(&FP0, &value);
    ASSERT_FLOAT_EQ(value, expected1->e, expected1->t);
}

void test_evaluate_expression(void) {
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

void test_evaluate_expression_precedence(void) {

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
    ASSERT_FLOAT_EQ(value, 127, 0x00000000);
}

void test_one_string_comparison(char op, const char* s1, const char* s2, const Float* expected, int line) {
    char line_data[40];
    size_t s1_length, s2_length;
    size_t i;
    Float value;

    fprintf(stderr, "  %s:%d: test_one_string_comparison(%d, \"%s\", \"%s\")\n", __FILE__, line, op, s1, s2);

    s1_length = strlen(s1);
    s2_length = strlen(s2);

    i = 0;
    line_data[i++] = TOKEN_STRING;
    line_data[i++] = (char)s1_length;
    memcpy(line_data + i, s1, s1_length);
    i += s1_length;
    line_data[i++] = TOKEN_OP | op;
    line_data[i++] = TOKEN_STRING;
    line_data[i++] = (char)s2_length;
    memcpy(line_data + i, s2, s2_length);
    i += s2_length;
    line_data[i++] = TOKEN_NO_VALUE;
    set_line(0, line_data, i);

    evaluate_expression();
    ASSERT_EQ(err, 0);
    pop_fp0();
    store_fpx(&FP0, &value);
    ASSERT_FLOAT_EQ(value, expected->e, expected->t);
}

void test_string_comparison(void) {
    const Float value_0 = { 0x00000000, 0 };
    const Float value_1 = { 0x00000000, 127 };

    PRINT_TEST_NAME();

    test_one_string_comparison(OP_EQ, "HELLO", "HELLO", &value_1, __LINE__);
    test_one_string_comparison(OP_EQ, "HELLO", "HELLOX", &value_0, __LINE__);
    test_one_string_comparison(OP_EQ, "HELLOX", "HELLO", &value_0, __LINE__);
    test_one_string_comparison(OP_EQ, "ABC", "XYZ", &value_0, __LINE__);
    test_one_string_comparison(OP_EQ, "", "", &value_1, __LINE__);

    test_one_string_comparison(OP_NE, "HELLO", "HELLO", &value_0, __LINE__);
    test_one_string_comparison(OP_NE, "HELLO", "HELLOX", &value_1, __LINE__);
    test_one_string_comparison(OP_NE, "HELLOX", "HELLO", &value_1, __LINE__);
    test_one_string_comparison(OP_NE, "ABC", "XYZ", &value_1, __LINE__);
    test_one_string_comparison(OP_NE, "", "", &value_0, __LINE__);

    test_one_string_comparison(OP_LT, "HELLO", "HELLO", &value_0, __LINE__);
    test_one_string_comparison(OP_LT, "HELLO", "HELLOX", &value_1, __LINE__);
    test_one_string_comparison(OP_LT, "HELLOX", "HELLO", &value_0, __LINE__);
    test_one_string_comparison(OP_LT, "ABC", "XYZ", &value_1, __LINE__);
    test_one_string_comparison(OP_LT, "", "", &value_0, __LINE__);

    test_one_string_comparison(OP_LE, "HELLO", "HELLO", &value_1, __LINE__);
    test_one_string_comparison(OP_LE, "HELLO", "HELLOX", &value_1, __LINE__);
    test_one_string_comparison(OP_LE, "HELLOX", "HELLO", &value_0, __LINE__);
    test_one_string_comparison(OP_LE, "ABC", "XYZ", &value_1, __LINE__);
    test_one_string_comparison(OP_LE, "", "", &value_1, __LINE__);

    test_one_string_comparison(OP_GT, "HELLO", "HELLO", &value_0, __LINE__);
    test_one_string_comparison(OP_GT, "HELLO", "HELLOX", &value_0, __LINE__);
    test_one_string_comparison(OP_GT, "HELLOX", "HELLO", &value_1, __LINE__);
    test_one_string_comparison(OP_GT, "ABC", "XYZ", &value_0, __LINE__);
    test_one_string_comparison(OP_GT, "", "", &value_0, __LINE__);

    test_one_string_comparison(OP_GE, "HELLO", "HELLO", &value_1, __LINE__);
    test_one_string_comparison(OP_GE, "HELLO", "HELLOX", &value_0, __LINE__);
    test_one_string_comparison(OP_GE, "HELLOX", "HELLO", &value_1, __LINE__);
    test_one_string_comparison(OP_GE, "ABC", "XYZ", &value_0, __LINE__);
    test_one_string_comparison(OP_GE, "", "", &value_1, __LINE__);
}

int main(void) {
    initialize_target();
    test_stack_alloc_free();
    test_evaluate_expression();
    test_evaluate_expression_precedence();
    test_string_comparison();
    return 0;
}
