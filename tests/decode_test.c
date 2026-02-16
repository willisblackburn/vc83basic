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
    const char line_data[] = { '1', '0', '0', ',', '4', '1', '1', '2', ',', '3', '.', '1', '4', '1', '5', '9', ',' };

    PRINT_TEST_NAME();

    set_line(0, line_data, sizeof line_data);

    decode_number();
    decode_byte();
    ASSERT_FP_FIELDS_EQ(FP0, POSITIVE, 134, 0xC8000000);

    decode_number();
    decode_byte();
    ASSERT_FP_FIELDS_EQ(FP0, POSITIVE, 140, 0x80800000);

    decode_number();
    decode_byte();
    ASSERT_FP_FIELDS_EQ(FP0, POSITIVE, 129, 0xC90FCF81);
}

void test_decode_string(void) {
    const char line_data[] = {
        '"', 'H', 'E', 'L', 'L', 'O', '"'
    };

    PRINT_TEST_NAME();

    initialize_program();

    set_line(0, line_data, sizeof line_data);

    HEXDUMP(&line_buffer, 32);
    HEXDUMP(line_ptr, 32);

    decode_string();
    HEXDUMP(string_ptr, 32);
    ASSERT_EQ(string_ptr->length, 5);
    ASSERT_EQ(memcmp(string_ptr->data, "HELLO", 5), 0);
    ASSERT_EQ(line_pos, 10);
}

void test_decode_name(void) {
    const char line_data[] = {
        'X' | EOT,
        'T', 'H', 'I', 'N', 'G', '3' | EOT,
        'A', '$' | EOT,
        'X' | EOT, '(',
        'A', '$' | EOT, '(',
     };

    PRINT_TEST_NAME();

    set_line(0, line_data, sizeof line_data);

    decode_name();
    ASSERT_PTR_EQ(decode_name_ptr, line_buffer.data);
    ASSERT_EQ(decode_name_length, 1);
    ASSERT_EQ(decode_name_type, TYPE_NUMBER);
    ASSERT_EQ(decode_name_arity, 0);

    decode_name();
    ASSERT_PTR_EQ(decode_name_ptr, line_buffer.data + 1);
    ASSERT_EQ(decode_name_length, 6);
    ASSERT_EQ(decode_name_type, TYPE_NUMBER);
    ASSERT_EQ(decode_name_arity, 0);

    decode_name();
    ASSERT_PTR_EQ(decode_name_ptr, line_buffer.data + 7);
    ASSERT_EQ(decode_name_length, 2);
    ASSERT_EQ(decode_name_type, TYPE_STRING);
    ASSERT_EQ(decode_name_arity, 0);

    decode_name();
    ASSERT_PTR_EQ(decode_name_ptr, line_buffer.data + 9);
    ASSERT_EQ(decode_name_length, 1);
    ASSERT_EQ(decode_name_type, TYPE_NUMBER);
    ASSERT_EQ(decode_name_arity, -1);

    decode_name();
    ASSERT_PTR_EQ(decode_name_ptr, line_buffer.data + 11);
    ASSERT_EQ(decode_name_length, 2);
    ASSERT_EQ(decode_name_type, TYPE_STRING);
    ASSERT_EQ(decode_name_arity, -1);
}

extern void* decode_xh_vectors[];

int unary_op_count;

void xh_unary_operator(void) {
    char op = decode_byte() & (char)~TOKEN_UNARY_OP;
    switch (++unary_op_count) {
        case 1: ASSERT_EQ(op, UNARY_OP_MINUS); break;
        case 2: ASSERT_EQ(op, UNARY_OP_NOT); break;
    }
    __asm__("clc");
}

int op_count;

void xh_operator(void) {
    char op = decode_byte()  & (char)~TOKEN_OP;
    switch (++op_count) {
        case 1: ASSERT_EQ(op, OP_ADD); break;
        case 2: ASSERT_EQ(op, OP_DIV); break;
        case 3: ASSERT_EQ(op, OP_MUL); break;
        case 4: ASSERT_EQ(op, OP_OR); break;
        case 5: ASSERT_EQ(op, OP_SUB); break;
    }
    __asm__("clc");
}

int num_count;

void xh_number(void) {
    decode_number();
    switch (++num_count) {
        case 1: ASSERT_FP_FIELDS_EQ(FP0, POSITIVE, 140, 0x80800000); break;
        case 2: ASSERT_FP_FIELDS_EQ(FP0, POSITIVE, 129, 0xC0000000); break;
    }
    __asm__("clc");
}

void xh_string(void) {
    decode_string();
    // Don't do anything with strings
    __asm__("clc");
}

int var_count;

void xh_variable(void) {
    decode_name();
    ++var_count;
    ASSERT_EQ((unsigned char)*decode_name_ptr, 'X' | EOT);
    __asm__("clc");
}

int function_count;

void xh_function(void) {
    char function = decode_byte()  & (char)~TOKEN_FUNCTION;
    ++function_count;
    ASSERT_EQ(function, 0);
    __asm__("clc");
}

int paren_count;

void xh_paren(void) {
    ++paren_count;
    decode_byte();
    decode_expression(decode_xh_vectors);
    // Consume ')'
    decode_byte();
    __asm__("clc");
}


void* decode_xh_vectors[] = {
    (char*)xh_unary_operator - 1,
    (char*)xh_operator - 1,
    (char*)xh_number - 1,
    (char*)xh_string - 1,
    (char*)xh_variable - 1,
    (char*)xh_function - 1,
    (char*)xh_paren - 1,
};

void test_decode_expression(void) {

    // 4112+(X/3)*-X OR NOT X-LEN("HELLO")
    const char line_data[] = {
        '4', '1', '1', '2',
        TOKEN_OP | OP_ADD,        
        '(',
        'X' | EOT,
        TOKEN_OP | OP_DIV,              
        '3',
        ')',
        TOKEN_OP | OP_MUL, 
        TOKEN_UNARY_OP | UNARY_OP_MINUS,             
        'X' | EOT,
        TOKEN_OP | OP_OR,
        TOKEN_UNARY_OP | UNARY_OP_NOT,
        'X' | EOT,
        TOKEN_OP | OP_SUB,
        0 | TOKEN_FUNCTION,
        '"', 'H', 'E', 'L', 'L', 'O', '"', ')',
        0
    };

    PRINT_TEST_NAME();

    set_line(0, line_data, sizeof line_data);

    decode_expression(decode_xh_vectors);
    ASSERT_EQ(num_count, 2);
    ASSERT_EQ(var_count, 3);
    ASSERT_EQ(op_count, 5);
    ASSERT_EQ(unary_op_count, 2);
    ASSERT_EQ(function_count, 1);
    ASSERT_EQ(paren_count, 1);
}

int main(void) {
    initialize_target();
    test_decode_byte();
    test_decode_number();
    test_decode_string();
    test_decode_name();
    test_decode_expression();
    return 0;
}