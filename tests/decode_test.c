#include "test.h"

void test_decode_byte(void) {
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

void test_decode_number(void) {
    int value;
    const char line_data[] = {  TOKEN_NUM, 0, 0, TOKEN_NUM, 0, 1, TOKEN_NUM, 1, 3 };

    PRINT_TEST_NAME();

    set_line(0, line_data, sizeof line_data);

    value = decode_number();
    ASSERT_EQ(value, 0);

    value = decode_number();
    ASSERT_EQ(value, 256);

    value = decode_number();
    ASSERT_EQ(value, 769);
}

void test_decode_name(void) {
    const char line_data[] = {  'X' | NT_STOP, 'T', 'H', 'I', 'N', 'G', '3' | NT_STOP };

    PRINT_TEST_NAME();

    set_line(0, line_data, sizeof line_data);

    decode_name();
    ASSERT_EQ(name_ptr, line_buffer.data);
    ASSERT_EQ(name_length, 1);

    decode_name();
    ASSERT_EQ(name_ptr, line_buffer.data + 1);
    ASSERT_EQ(name_length, 6);
}

extern void* decode_xh_vectors[];

int var_count;

void xh_variable(void) {
    decode_name();
    ++var_count;
    ASSERT_EQ(*name_ptr, 'X' | NT_STOP);
}

int op_count;

void xh_operator(void) {
    char op = decode_operator();
    switch (++op_count) {
        case 1: ASSERT_EQ(op, OP_ADD); break;
        case 2: ASSERT_EQ(op, OP_DIV); break;
        case 3: ASSERT_EQ(op, OP_MUL); break;
        case 4: ASSERT_EQ(op, OP_OR); break;
    }
}

int unary_op_count;

void xh_unary_operator(void) {
    char op = decode_unary_operator();
    switch (++unary_op_count) {
        case 1: ASSERT_EQ(op, UNARY_OP_MINUS); break;
        case 2: ASSERT_EQ(op, UNARY_OP_NOT); break;
    }
}

int num_count;

void xh_number(void) {
    int value = decode_number();
    switch (++num_count) {
        case 1: ASSERT_EQ(value, 4112); break;
        case 2: ASSERT_EQ(value, 3); break;
    }
}

int paren_count;

void xh_paren(void) {
    ++paren_count;
    fprintf(stderr, "**** (\n");
    decode_expression(decode_xh_vectors);
    fprintf(stderr, "**** )\n");
}

void* decode_xh_vectors[] = {
    (char*)xh_variable - 1,
    (char*)xh_operator - 1,
    (char*)xh_unary_operator - 1,
    (char*)xh_number - 1,
    (char*)xh_paren - 1,
};

void test_decode_expression(void) {

    const char line_data[] = {
        TOKEN_NUM, 0x10, 0x10,          // 4,112
        TOKEN_OP | OP_ADD,        
        TOKEN_PAREN,
        'X' | NT_STOP,                  // X
        TOKEN_OP | OP_DIV,              
        TOKEN_NUM, 0x03, 0x00,          // 3
        TOKEN_NO_VALUE,
        TOKEN_OP | OP_MUL, 
        TOKEN_UNARY_OP | UNARY_OP_MINUS,             
        'X' | NT_STOP,                  // X
        TOKEN_OP | OP_OR,
        TOKEN_UNARY_OP | UNARY_OP_NOT,
        'X' | NT_STOP,                  // X
        TOKEN_NO_VALUE
    };

    PRINT_TEST_NAME();

    set_line(0, line_data, sizeof line_data);

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
    test_decode_name();
    test_decode_expression();
    return 0;
}