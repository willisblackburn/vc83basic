#include "test.h"

static int var_count;

static void xh_variable(void) {
    __asm__ ("stx %v", reg_x);
    ++var_count;
    ASSERT_EQ(reg_x, TOKEN_VAR | 1);
}

static int num_count;

static void xh_number(void) {
    int value = decode_number(line_ptr, lp);
    switch (++num_count) {
        case 1: ASSERT_EQ(value, 4112); break;
        case 2: ASSERT_EQ(value, 3); break;
    }
}

static int op_count;

static void xh_operator(void) {
    __asm__ ("stx %v", reg_x);
    switch (++op_count) {
        case 1: ASSERT_EQ(reg_x, TOKEN_OP | OP_ADD); break;
        case 2: ASSERT_EQ(reg_x, TOKEN_OP | OP_DIV); break;
        case 3: ASSERT_EQ(reg_x, TOKEN_OP | OP_SUB); break;
    }
}

static int lparen_count, rparen_count;

static void xh_paren(void) {
    __asm__ ("stx %v", reg_x);
    if (reg_x == TOKEN_LPAREN) {
        ++lparen_count;
    } else if (reg_x == TOKEN_RPAREN) {
        ++rparen_count;
    }
}

static int minus_count, not_count;

static void xh_unary(void) {
    __asm__ ("stx %v", reg_x);
    if (reg_x == TOKEN_MINUS) {
        ++minus_count;
    } else if (reg_x == TOKEN_NOT) {
        ++not_count;
    }
}

static void test_decode_expression(void) {

    Line line = { // 4112+(X/3) OR NOT -X where X is variable 1
        16,
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
            TOKEN_NOT,
            TOKEN_MINUS,             
            TOKEN_VAR | 1,                  // X
            TOKEN_NO_VALUE
        }
    };

    void* decode_xh_vectors[] = {
        xh_variable,
        xh_number,
        xh_operator,
        xh_paren,
        xh_paren,
        xh_unary,
        xh_unary,
    };

    PRINT_TEST_NAME();

    vector_table_ptr = decode_xh_vectors;
    decode_expression(&line, offsetof(Line, data));
    ASSERT_EQ(num_count, 2);
    ASSERT_EQ(var_count, 2);
    ASSERT_EQ(lparen_count, 1);
    ASSERT_EQ(rparen_count, 1);
    ASSERT_EQ(minus_count, 1);
    ASSERT_EQ(not_count, 1);
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