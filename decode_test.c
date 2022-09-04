#include "test.h"

static int handle_integer_count;

static void handle_integer(void) {
    switch (++handle_integer_count) {
        case 1: ASSERT_EQ(reg_bc, 4112); break;
        case 2: ASSERT_EQ(reg_bc, 3); break;
        case 3: ASSERT_EQ(reg_bc, 1); break;
    }
}

static int handle_variable_count;

static void handle_variable(void) {
    ++handle_variable_count;
    ASSERT_EQ(reg_b, 1);
}

static int handle_subexpression_count;

static void handle_subexpression(void) {
    ++handle_subexpression_count;
    decode_expression();
}

static int handle_operator_count;

static void handle_operator(void) {
    switch (++handle_operator_count) {
        case 1: ASSERT_EQ(reg_b, OP_ADD); break;
        case 2: ASSERT_EQ(reg_b, OP_DIV); break;
        case 3: ASSERT_EQ(reg_b, OP_SUB); break;
    }
}

static void test_decode_expression(void) {

    Line line = { // 4112+(X/3)-1 where X is variable 1
        15,
        10,
        {
            TOKEN_NUM, 0x10, 0x10,          // 4,112
            TOKEN_OP | OP_ADD,        
            TOKEN_LPAREN,
            TOKEN_VAR | 1,                  // X
            TOKEN_OP | OP_DIV,              
            TOKEN_NUM, 0x03, 0x00,          // 3
            TOKEN_RPAREN,
            TOKEN_OP | OP_SUB,              
            TOKEN_NUM, 0x01, 0x00,          // 1
        }
    };

    void* vector_table[] = {
        handle_integer,
        handle_variable,
        handle_subexpression,
        handle_operator,
    };

    PRINT_TEST_NAME();

    vector_table_ptr = vector_table;
    set_line_ptr(&line);
    lp = offsetof(Line, data);
    decode_expression();
    ASSERT_EQ(handle_integer_count, 3);
    ASSERT_EQ(handle_variable_count, 1);
    ASSERT_EQ(handle_subexpression_count, 1);
    ASSERT_EQ(handle_operator_count, 3);
}

static void test_decode_byte(void) {
    char byte_value;
    const char line_data[] = { 0, 0, 1, 3 };

    PRINT_TEST_NAME();

    byte_value = decode_byte(line_data, 0);
    ASSERT_EQ(byte_value, 0);

    byte_value = decode_byte(line_data, 2);
    ASSERT_EQ(byte_value, 1);
}

static void test_decode_number(void) {
    int value;
    const char line_data[] = { 0, 0, 1, 3 };

    PRINT_TEST_NAME();

    value = decode_number(line_data, 0);
    ASSERT_EQ(value, 0);

    value = decode_number(line_data, 1);
    ASSERT_EQ(value, 256);

    value = decode_number(line_data, 2);
    ASSERT_EQ(value, 769);
}

int main(void) {
    initialize_target();
    test_decode_expression();
    test_decode_byte();
    test_decode_number();
    return 0;
}