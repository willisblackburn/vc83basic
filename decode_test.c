 #include "test.h"

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

extern void* decode_xh_vectors[];

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

static int op_count;

static void xh_operator(void) {
    char op = decode_operator();
    switch (++op_count) {
        case 1: ASSERT_EQ(op, OP_ADD); break;
        case 2: ASSERT_EQ(op, OP_DIV); break;
        case 3: ASSERT_EQ(op, OP_MUL); break;
        case 4: ASSERT_EQ(op, OP_OR); break;
    }
}

static int unary_op_count;

static void xh_unary_operator(void) {
    char op = decode_unary_operator();
    switch (++unary_op_count) {
        case 1: ASSERT_EQ(op, UNARY_OP_MINUS); break;
        case 2: ASSERT_EQ(op, UNARY_OP_NOT); break;
    }
}

static int paren_count;

static void xh_paren(void) {
    ++paren_count;
    decode_expression(decode_xh_vectors, line_ptr, lp);
}

void* decode_xh_vectors[] = {
    xh_variable,
    xh_number,
    xh_operator,
    xh_unary_operator,
    xh_paren,
};

static void test_decode_expression(void) {

    Line line = { // 4112+(X/3)*-X OR NOT X where X is variable 1
        16,
        10,
        {
            TOKEN_NUM, 0x10, 0x10,          // 4,112
            TOKEN_OP | OP_ADD,        
            TOKEN_PAREN,
            TOKEN_VAR | 1,                  // X
            TOKEN_OP | OP_DIV,              
            TOKEN_NUM, 0x03, 0x00,          // 3
            TOKEN_NO_VALUE,
            TOKEN_OP | OP_MUL, 
            TOKEN_UNARY_OP | UNARY_OP_MINUS,             
            TOKEN_VAR | 1,                  // X
            TOKEN_OP | OP_OR,
            TOKEN_UNARY_OP | UNARY_OP_NOT,
            TOKEN_VAR | 1,                  // X
            TOKEN_NO_VALUE
        }
    };

    PRINT_TEST_NAME();

    decode_expression(decode_xh_vectors, &line, offsetof(Line, data));
    ASSERT_EQ(num_count, 2);
    ASSERT_EQ(var_count, 3);
    ASSERT_EQ(op_count, 4);
    ASSERT_EQ(unary_op_count, 2);
    ASSERT_EQ(paren_count, 1);
}

int main(void) {
    initialize_target();
    test_decode_byte();
    test_decode_number();
    test_decode_expression();
    return 0;
}