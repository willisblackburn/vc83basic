 #include "test.h"

static void test_decode_byte(void) {
    char byte_value;
    const char line_data[] = {
        0x00, 0x01, 0x03
    };

    PRINT_TEST_NAME();

    set_line(0, line_data, sizeof line_data);

    byte_value = decode_byte();
    ASSERT_EQ(byte_value, 0x00);

    byte_value = decode_byte();
    ASSERT_EQ(byte_value, 0x01);

    byte_value = decode_byte();
    ASSERT_EQ(byte_value, 0x03);
}

static void test_decode_number(void) {
    const char line_data[] = {
        TOKEN_NUM, 0x00, 0x00, 0x00, 0x48, 133,
        TOKEN_NUM, 0x00, 0x00, 0x80, 0x00, 139,
        TOKEN_NUM, 0x81, 0xCF, 0x0F, 0x49, 128
    };

    PRINT_TEST_NAME();

    set_line(0, line_data, sizeof line_data);

    decode_number();
    ASSERT_FPX_EQ(FP0, POSITIVE, 133, 0xC8000000);

    decode_number();
    ASSERT_FPX_EQ(FP0, POSITIVE, 139, 0x80800000);

    decode_number();
    ASSERT_FPX_EQ(FP0, POSITIVE, 128, 0xC90FCF81);
}

extern void* decode_xh_vectors[];

static int num_count;

static void xh_number(void) {
    decode_number();
    switch (++num_count) {
        case 1: ASSERT_FPX_EQ(FP0, POSITIVE, 139, 0x80800000); break;
        case 2: ASSERT_FPX_EQ(FP0, POSITIVE, 128, 0xC0000000); break;
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
    decode_expression(decode_xh_vectors);
}

void* decode_xh_vectors[] = {
    xh_variable,
    xh_number,
    xh_operator,
    xh_unary_operator,
    xh_paren,
};

static void test_decode_expression(void) {
    const char line_data[] = {
        TOKEN_NUM, 0x00, 0x00, 0x80, 0x00, 139,  // 4,112
        TOKEN_OP | OP_ADD,
        TOKEN_PAREN,
        TOKEN_VAR | 1, // X
        TOKEN_OP | OP_DIV,
        TOKEN_NUM, 0x00, 0x00, 0x00, 0x40, 128, // 3
        TOKEN_NO_VALUE,
        TOKEN_OP | OP_MUL,
        TOKEN_UNARY_OP | UNARY_OP_MINUS,             
        TOKEN_VAR | 1, // X
        TOKEN_OP | OP_OR,
        TOKEN_UNARY_OP | UNARY_OP_NOT,
        TOKEN_VAR | 1, // X
        TOKEN_NO_VALUE
    };

    PRINT_TEST_NAME();

    set_line(line_data, sizeof line_data);

    decode_expression(decode_xh_vectors);
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