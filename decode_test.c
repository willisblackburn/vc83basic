#include "test.h"

static int num_count;

static void xh_number(void) {
    int value = decode_number(line_ptr, lp);
    switch (++num_count) {
        case 1: ASSERT_EQ(value, 4112); break;
        case 2: ASSERT_EQ(value, 3); break;
    }
}

static int var_count;

static void xh_variable(void) {
    char var = decode_variable();
    ++var_count;
    ASSERT_EQ(var, 1);
}

static int lparen_count, rparen_count;

static void xh_lparen(void) {
    ++lparen_count;
}

static void xh_rparen(void) {
    ++rparen_count;
}

static int op_count;

static void xh_operator(void) {
    char op = decode_operator();
    switch (++op_count) {
        case 1: ASSERT_EQ(op, OP_ADD); break;
        case 2: ASSERT_EQ(op, OP_DIV); break;
        case 3: ASSERT_EQ(op, OP_SUB); break;
    }
}

static int minus_count, not_count;

static void xh_minus(void) {
    ++minus_count;
}

static void xh_not(void) {
    ++not_count;
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
        xh_lparen,
        xh_rparen,
        xh_minus,
        xh_not,
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
    const char line_data_1[] = { TOKEN_NUM, 0, 0, TOKEN_NUM, 0, 1 };
    const char line_data_2[] = { TOKEN_NUM, 1, 3 };

    PRINT_TEST_NAME();

    value = decode_number(line_data_1, 0);
    ASSERT_EQ(value, 0);

    value = decode_number(line_data_1, 3);
    ASSERT_EQ(value, 256);

    value = decode_number(line_data_2, 0);
    ASSERT_EQ(value, 769);
}

int main(void) {
    initialize_target();
    test_decode_expression();
    test_decode_byte();
    test_decode_number();
    return 0;
}