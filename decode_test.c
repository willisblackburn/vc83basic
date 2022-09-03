#include "test.h"

static void handle_unused(void) {
}

static void handle_variable(void) {
    __asm__ ("stx %v", reg_x);
    ASSERT_EQ(reg_x, TOKEN_VAR | 3);
}

static void handle_function(void) {
    __asm__ ("stx %v", reg_x);
    ASSERT_EQ(reg_x, TOKEN_FUNC | 2);
}

static void handle_small_integer_literal(void) {
    __asm__ ("stx %v", reg_x);
    ASSERT_EQ(reg_x, TOKEN_SMALL_INT - 3 + 16);
}

static void handle_operator(void) {
    __asm__ ("stx %v", reg_x);
    ASSERT_EQ(reg_x, TOKEN_OP | OP_DIV);
}

static void handle_no_value(void) {
    __asm__ ("stx %v", reg_x);
    ASSERT_EQ(reg_x, TOKEN_NO_VALUE);
}

static void handle_integer_literal(void) {
    __asm__ ("stx %v", reg_x);
    ASSERT_EQ(reg_x, TOKEN_INT);
    lp += 2;
}

static void handle_string_literal(void) {
    __asm__ ("stx %v", reg_x);
    ASSERT_EQ(reg_x, TOKEN_STRING);
    lp += 6;
}

static void handle_floating_point_literal(void) {
    __asm__ ("stx %v", reg_x);
    ASSERT_EQ(reg_x, TOKEN_FLOAT);
    lp += 5;
}

static void handle_small_floating_point_literal(void) {
    __asm__ ("stx %v", reg_x);
    ASSERT_EQ(reg_x, TOKEN_SMALL_FLOAT);
    lp += 2;
}

static void handle_left_paren(void) {
    __asm__ ("stx %v", reg_x);
    ASSERT_EQ(reg_x, TOKEN_LPAREN);
}

static void handle_right_paren(void) {
    __asm__ ("stx %v", reg_x);
    ASSERT_EQ(reg_x, TOKEN_RPAREN);
}

static void handle_not(void) {
    __asm__ ("stx %v", reg_x);
    ASSERT_EQ(reg_x, TOKEN_NOT);
}

static void handle_unary_minus(void) {
    __asm__ ("stx %v", reg_x);
    ASSERT_EQ(reg_x, TOKEN_MINUS);
}

static void handle_print_comma(void) {
    __asm__ ("stx %v", reg_x);
    ASSERT_EQ(reg_x, TOKEN_COMMA);
}

static void handle_print_semi(void) {
    __asm__ ("stx %v", reg_x);
    ASSERT_EQ(reg_x, TOKEN_SEMI);
}

static void test_decode_dispatch_next(void) {

    Line line = {
        29,
        10,
        {
            TOKEN_VAR | 3,                  // variable 3
            TOKEN_FUNC | 2,                 // function 2
            TOKEN_SMALL_INT -3 + 16,        // integer -3 with bias of 16
            TOKEN_OP | OP_DIV,              // divide
            TOKEN_NO_VALUE,
            TOKEN_INT, 0x10, 0x10,          // integer value 4,112
            TOKEN_STRING, 5, 'H', 'E', 'L', 'L', 'O',
            TOKEN_FLOAT, 0x00, 0x00, 0x00, 0x00, 0x00,
            TOKEN_SMALL_FLOAT, 0x00, 0x00,
            TOKEN_LPAREN,
            TOKEN_RPAREN,
            TOKEN_NOT,
            TOKEN_MINUS,
            TOKEN_COMMA,
            TOKEN_SEMI,
        }
    };
    void* vector_table[] = {
        handle_variable,
        handle_function,
        handle_small_integer_literal,
        handle_operator,
        handle_no_value,
        handle_integer_literal,
        handle_string_literal,
        handle_floating_point_literal,
        handle_small_floating_point_literal,
        handle_unused,
        handle_left_paren,
        handle_right_paren,
        handle_not,
        handle_unary_minus,
        handle_print_comma,
        handle_print_semi,
    };

    PRINT_TEST_NAME();

    line_ptr = &line;
    lp = 3;
    vector_table_ptr = vector_table;
    while (lp < line.next_line_offset) {
        DEBUG(lp);
        decode_dispatch_next();
    }
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
    test_decode_dispatch_next();
    test_decode_byte();
    test_decode_number();
    return 0;
}