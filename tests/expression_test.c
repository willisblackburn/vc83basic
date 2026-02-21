/*
 * SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
 *
 * SPDX-License-Identifier: MIT
 */

#include "test.h"

void test_stack_alloc_free(void) {
    char p;

    PRINT_TEST_NAME();

    initialize_program();

    ASSERT_EQ(op_stack_pos, OP_STACK_SIZE);
    ASSERT_EQ(stack_pos, PRIMARY_STACK_SIZE);

    p = stack_alloc(2);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(stack_pos, PRIMARY_STACK_SIZE - 2);
    ASSERT_EQ(p, stack_pos);

    p = stack_alloc(64);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(stack_pos, PRIMARY_STACK_SIZE - 2 - 64);
    ASSERT_EQ(p, stack_pos);

    stack_free(64);
    ASSERT_EQ(stack_pos, PRIMARY_STACK_SIZE - 2);

    stack_free(2);
    ASSERT_EQ(stack_pos, PRIMARY_STACK_SIZE);

    // Test overflow; no matter what PRIMARY_STACK_SIZE is, allocating 96 three times should overflow
    stack_alloc(96);
    stack_alloc(96);
    stack_alloc(96);
    ASSERT_EQ(err, ERR_STACK_OVERFLOW);
}

void test_one_op(char op, const Float* expected00, const Float* expected01, const Float* expected10, 
    const Float* expected11) {

    Float value;
    // Terminate expression with 0.
    char line_data[] = { '0', 0 /* op */, '0', 0 };

    DEBUG(op);

    line_data[1] = TOKEN_OP | op;
    line_data[0] = '0';
    line_data[2] = '0';
    set_line(0, line_data, sizeof line_data);
    evaluate_expression();
    ASSERT_EQ(err, 0);
    pop_fp0();
    store_fp0(&value);
    ASSERT_FLOAT_EQ(value, *expected00);

    line_data[0] = '0';
    line_data[2] = '1';
    set_line(0, line_data, sizeof line_data);
    evaluate_expression();
    ASSERT_EQ(err, 0);
    store_fp0(&value);
    ASSERT_FLOAT_EQ(value, *expected01);

    line_data[0] = '1';
    line_data[2] = '0';
    set_line(0, line_data, sizeof line_data);
    evaluate_expression();
    ASSERT_EQ(err, 0);
    pop_fp0();
    store_fp0(&value);
    ASSERT_FLOAT_EQ(value, *expected10);

    line_data[0] = '1';
    line_data[2] = '1';
    set_line(0, line_data, sizeof line_data);
    evaluate_expression();
    ASSERT_EQ(err, 0);
    pop_fp0();
    store_fp0(&value);
    ASSERT_FLOAT_EQ(value, *expected11);
}

void test_one_unary_op(char op, const Float* expected0, const Float* expected1) {

    // Terminate expression with 0.
    char line_data[] = { 0 /* op */, '0', 0 };
    Float value;

    DEBUG(op);

    line_data[0] = TOKEN_UNARY_OP | op;
    line_data[1] = '0';
    set_line(0, line_data, sizeof line_data);
    evaluate_expression();
    ASSERT_EQ(err, 0);
    pop_fp0();
    store_fp0(&value);
    ASSERT_FLOAT_EQ(value, *expected0);

    line_data[1] = '1';
    set_line(0, line_data, sizeof line_data);
    evaluate_expression();
    ASSERT_EQ(err, 0);
    pop_fp0();
    store_fp0(&value);
    ASSERT_FLOAT_EQ(value, *expected1);
}

void test_evaluate_expression_op(void) {
    const Float value_0 = { 0x00000000, 0 };
    const Float value_1 = { 0x00000000, 128 };
    const Float value_negative_1 = { 0x80000000, 128 };
    const Float value_2 = { 0x00000000, 129 };

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

    test_one_unary_op(UNARY_OP_MINUS, &value_0, &value_negative_1);
    test_one_unary_op(UNARY_OP_NOT, &value_1, &value_0);
}

void test_evaluate_expression_op_precedence(void) {
    Float value;

    // Terminate each expression with 0.
    // 2-1-1 = 0
    char line_data_1[] = { '2', TOKEN_OP | OP_SUB, '1', TOKEN_OP | OP_SUB, '1', 0 };
    Float result_1 = { 0x00000000, 0 };
    // 2-(1-1) = 2
    char line_data_2[] = { '2', TOKEN_OP | OP_SUB, '(', '1', TOKEN_OP | OP_SUB, '1', ')', 0 };
    Float result_2 = { 0x00000000, 129 };

    PRINT_TEST_NAME();

    initialize_program();

    set_line(0, line_data_1, sizeof line_data_1);
    evaluate_expression();
    ASSERT_EQ(err, 0);
    pop_fp0();
    store_fp0(&value);
    ASSERT_FLOAT_EQ(value, result_1);

    set_line(0, line_data_2, sizeof line_data_2);
    evaluate_expression();
    ASSERT_EQ(err, 0);
    pop_fp0();
    store_fp0(&value);
    ASSERT_FLOAT_EQ(value, result_2);
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
    line_data[i++] = '"';
    memcpy(line_data + i, s1, s1_length);
    i += s1_length;
    line_data[i++] = '"';
    line_data[i++] = TOKEN_OP | op;
    line_data[i++] = '"';
    memcpy(line_data + i, s2, s2_length);
    i += s2_length;
    line_data[i++] = '"';
    line_data[i++] = 0;
    set_line(0, line_data, i);

    evaluate_expression();
    ASSERT_EQ(err, 0);
    pop_fp0();
    store_fp0(&value);
    ASSERT_FLOAT_EQ(value, *expected);
}

void test_string_comparison(void) {
    const Float value_0 = { 0x00000000, 0 };
    const Float value_1 = { 0x00000000, 128 };

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

void test_evaluate_argument_list(void) {
    const char line_data[] = { '1', '2', '8', ',', '1', TOKEN_OP | OP_ADD, '2', 0 };
    const Float value_128 = { 0x00000000, 135 };
    const Float value_3 = { 0x40000000, 129 };

    Float value = { 0x00000000, 0 };
    signed char skipped_arguments;

    PRINT_TEST_NAME();

    initialize_program();
    ASSERT_EQ(stack_pos, PRIMARY_STACK_SIZE);

    set_line(0, line_data, sizeof line_data);
    skipped_arguments = evaluate_argument_list(5);
    ASSERT_EQ(skipped_arguments, 3);

    ASSERT_EQ(stack_pos, PRIMARY_STACK_SIZE - 12 /* 5 bytes plus 1 byte for type for each value */);

    pop_fp0();
    store_fp0(&value);
    ASSERT_FLOAT_EQ(value, value_3);

    pop_fp0();
    store_fp0(&value);
    ASSERT_FLOAT_EQ(value, value_128);

    ASSERT_EQ(stack_pos, PRIMARY_STACK_SIZE);
}

int main(void) {
    initialize_target();
    test_stack_alloc_free();
    test_evaluate_expression_op();
    test_evaluate_expression_op_precedence();
    test_string_comparison();
    test_evaluate_argument_list();
    return 0;
}
