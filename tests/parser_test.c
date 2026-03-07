/*
 * SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
 *
 * SPDX-License-Identifier: MIT
 */

#include "test.h"

void call_parse_pvm_expect_buffer_pos(const char* s, const char* start, const char* expect_line_data,
    size_t expect_line_data_length, size_t expect_buffer_pos, int line) {
    fprintf(stderr, "  %s:%d: parse_pvm(\"%s\")\n", __FILE__, line, s);
    strcpy(buffer, s);
    buffer_pos = 0;
    line_pos = offsetof(Line, data);
    parse_pvm(start);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(buffer_pos, expect_buffer_pos);
    if (expect_line_data) {
        ASSERT_MEMORY_EQ(line_buffer.data, expect_line_data, expect_line_data_length);
    }
    ASSERT_EQ(line_pos, offsetof(Line, data) + expect_line_data_length);
}

void call_parse_pvm(const char* s, const char* start, const char* expect_line_data,
    size_t expect_line_data_length, int line) {
    call_parse_pvm_expect_buffer_pos(s, start, expect_line_data, expect_line_data_length, strlen(s), line);
}

void test_pvm_number(void) {

    const char line_data_1[] = { '1' };
    const char line_data_2[] = { '9', '1' };
    const char line_data_3[] = { '-', '1', '0', '0' };
    const char line_data_4[] = { '3', '.', '1', '4', '1', '5', '9' };
    const char line_data_5[] = { '3', '.' };
    const char line_data_6[] = { '9', '8', '.', '6' };
    const char line_data_7[] = { '.', '3', '5', '0' };
    const char line_data_8[] = { '-', '.', '5' };
    const char line_data_9[] = { '1', '0', 'E', '5' };
    const char line_data_10[] = { '1', '0', '.', 'E', '5' };
    const char line_data_11[] = { '.', '1', '0', 'E', '5' };
    const char line_data_12[] = { '1', '0', 'E', '-', '5' };

    PRINT_TEST_NAME();

    call_parse_pvm("1", pvm_number, line_data_1, sizeof line_data_1, __LINE__);
    call_parse_pvm("91", pvm_number, line_data_2, sizeof line_data_2, __LINE__);
    call_parse_pvm_expect_buffer_pos("91X", pvm_number, line_data_2, sizeof line_data_2, 2, __LINE__);
    call_parse_pvm("  91", pvm_number, line_data_2, sizeof line_data_2, __LINE__);
    call_parse_pvm("-100", pvm_number, line_data_3, sizeof line_data_3, __LINE__);
    call_parse_pvm("  -100", pvm_number, line_data_3, sizeof line_data_3, __LINE__);
    call_parse_pvm("3.14159", pvm_number, line_data_4, sizeof line_data_4, __LINE__);
    call_parse_pvm("3.", pvm_number, line_data_5, sizeof line_data_5, __LINE__);
    call_parse_pvm("98.6", pvm_number, line_data_6, sizeof line_data_6, __LINE__);
    call_parse_pvm(".350", pvm_number, line_data_7, sizeof line_data_7, __LINE__);
    call_parse_pvm("-.5", pvm_number, line_data_8, sizeof line_data_8, __LINE__);
    call_parse_pvm("10E5", pvm_number, line_data_9, sizeof line_data_9, __LINE__);
    call_parse_pvm("10.E5", pvm_number, line_data_10, sizeof line_data_10, __LINE__);
    call_parse_pvm(".10E5", pvm_number, line_data_11, sizeof line_data_11, __LINE__);
    call_parse_pvm("10E-5", pvm_number, line_data_12, sizeof line_data_12, __LINE__);
}

void test_pvm_string(void) {

    const char line_data_1[] = { '"', 'H', 'E', 'L', 'L', 'O', '"' };
    const char line_data_2[] = { '"', '"' };
    const char line_data_3[] = { '"', 'I', 'N', 'T', 'E', 'R', 'N', 'A', 'L', ' ', '"', '"', 'Q', 'U', 'O', 'T', 'E', 'S', '"', '"', '"' };
    const char line_data_4[] = { '"', 'l', 'o', 'w', 'e', 'r', 'c', 'a', 's', 'e', '"' };

    PRINT_TEST_NAME();

    call_parse_pvm("\"HELLO\"", pvm_string, line_data_1, sizeof line_data_1, __LINE__);
    call_parse_pvm("\"\"", pvm_string, line_data_2, sizeof line_data_2, __LINE__);
    call_parse_pvm("  \"\"", pvm_string, line_data_2, sizeof line_data_2, __LINE__);
    call_parse_pvm("\"INTERNAL \"\"QUOTES\"\"\"", pvm_string, line_data_3, sizeof line_data_3, __LINE__);
    call_parse_pvm("\"lowercase\"", pvm_string, line_data_4, sizeof line_data_4, __LINE__);
}

void test_pvm_name(void) {

    const char line_data_1[] = { 'X' };
    const char line_data_2[] = { 'X', '1', '0' };
    const char line_data_3[] = { 'X', '_', '1', '0' };
    const char line_data_4[] = { 'X', '_', '1', '0', 'X' };
    const char line_data_5[] = { 'X', '9', 'A', 'P' };

    PRINT_TEST_NAME();

    call_parse_pvm("X", pvm_name, line_data_1, sizeof line_data_1, __LINE__);
    call_parse_pvm_expect_buffer_pos("X(", pvm_name, line_data_1, sizeof line_data_1, 1, __LINE__);
    call_parse_pvm("X10", pvm_name, line_data_2, sizeof line_data_2, __LINE__);
    call_parse_pvm("X_10", pvm_name, line_data_3, sizeof line_data_3, __LINE__);
    call_parse_pvm("X_10X", pvm_name, line_data_4, sizeof line_data_4, __LINE__);
    call_parse_pvm("X9AP", pvm_name, line_data_5, sizeof line_data_5, __LINE__);
}

void test_pvm_expression(void) {

    const char constant_line_data_1[] = { '1' };

    const char variable_line_data_1[] = { 'X' | EOT };
    const char variable_line_data_2[] = { 'S', '$' | EOT };
    const char variable_line_data_3[] = { 'X' | EOT, '(', '5', ')' };
    const char variable_line_data_4[] = { 'S', '$' | EOT, '(', '1', ',', '2', '5', ')'  };

    const char operator_line_data_1[] = { '1', TOKEN_OP | OP_ADD, '1' };
    const char operator_line_data_2[] = { '1', TOKEN_OP | OP_ADD, '1', TOKEN_OP | OP_DIV, '2' };
    const char operator_line_data_3[] = { '"', 'A', '"', TOKEN_OP | OP_CONCAT, '"', 'B', '"' };
    const char operator_line_data_4[] = { 'X' | EOT, TOKEN_OP | OP_AND, 'Y' | EOT };

    const char unary_operator_line_data_1[] = { '1', TOKEN_OP | OP_ADD, TOKEN_UNARY_OP | UNARY_OP_MINUS, 'A' | EOT };
    const char unary_operator_line_data_2[] = { TOKEN_UNARY_OP | UNARY_OP_NOT, '1' };

    const char parens_line_data_1[] = { '1', TOKEN_OP | OP_ADD, '(', '1', TOKEN_OP | OP_ADD, '1', ')' };
    const char parens_line_data_2[] = { 'X' | EOT, TOKEN_OP | OP_AND, '(', 'Y' | EOT, TOKEN_OP | OP_OR, TOKEN_UNARY_OP | UNARY_OP_NOT, 'Z' | EOT, ')' };

    const char function_line_data_1[] = { TOKEN_FUNCTION | 0, '(', '"', 'H', 'E', 'L', 'L', 'O', '"', ')' };
    const char function_line_data_2[] = { TOKEN_FUNCTION | 6, '(', '"', 'H', 'E', 'L', 'L', 'O', '"', ',', '2', ',', '3', ')' };

    PRINT_TEST_NAME();

    // Constants
    call_parse_pvm("1", pvm_expression, constant_line_data_1, sizeof constant_line_data_1, __LINE__);

    // Variables
    call_parse_pvm("X", pvm_expression, variable_line_data_1, sizeof variable_line_data_1, __LINE__);
    call_parse_pvm("S$", pvm_expression, variable_line_data_2, sizeof variable_line_data_2, __LINE__);
    call_parse_pvm("X(5)", pvm_expression, variable_line_data_3, sizeof variable_line_data_3, __LINE__);
    call_parse_pvm("S$(1,25)", pvm_expression, variable_line_data_4, sizeof variable_line_data_4, __LINE__);

    // Operators
    call_parse_pvm("1+1", pvm_expression, operator_line_data_1, sizeof operator_line_data_1, __LINE__);
    call_parse_pvm("  1+1", pvm_expression, operator_line_data_1, sizeof operator_line_data_1, __LINE__);
    call_parse_pvm("  1  +  1", pvm_expression, operator_line_data_1, sizeof operator_line_data_1, __LINE__);
    call_parse_pvm("1+1/2", pvm_expression, operator_line_data_2, sizeof operator_line_data_2, __LINE__);
    call_parse_pvm("\"A\" & \"B\"", pvm_expression, operator_line_data_3, sizeof operator_line_data_3, __LINE__);
    call_parse_pvm("X AND Y", pvm_expression, operator_line_data_4, sizeof operator_line_data_4, __LINE__);

    // Unary operators
    call_parse_pvm("1+-A", pvm_expression, unary_operator_line_data_1, sizeof unary_operator_line_data_1, __LINE__);
    call_parse_pvm("NOT 1", pvm_expression, unary_operator_line_data_2, sizeof unary_operator_line_data_2, __LINE__);

    // Parentheses
    call_parse_pvm("1+(1+1)", pvm_expression, parens_line_data_1, sizeof parens_line_data_1, __LINE__);
    call_parse_pvm("X AND (Y OR NOT Z)", pvm_expression, parens_line_data_2, sizeof parens_line_data_2, __LINE__);

    // Function
    call_parse_pvm("LEN(\"HELLO\")", pvm_expression, function_line_data_1, sizeof function_line_data_1, __LINE__);
    call_parse_pvm("MID$(\"HELLO\",2,3)", pvm_expression, function_line_data_2, sizeof function_line_data_2, __LINE__);
}

void test_pvm_statement(void) {

    const char simple_line_data_1[] = { ST_END };
    const char print_line_data_1[] = { ST_PRINT, '1' };
    const char print_line_data_2[] = { ST_PRINT, '1', ',', '"', 'Y', 'E', 'S', '"', ';', '(', '0', ')' };
    const char for_line_data_1[] = { ST_FOR, 'X' | EOT, '=', '1', TOKEN_CLAUSE | CLAUSE_TO, '5' };
    const char for_line_data_2[] = { ST_FOR, 'X' | EOT, '=', '1', TOKEN_CLAUSE | CLAUSE_TO, '2', '0', TOKEN_CLAUSE | CLAUSE_STEP, '2' };
    const char next_line_data_1[] = { ST_NEXT, 'X' | EOT };
    const char let_line_data_1[] = { ST_LET, 'X' | EOT, '=', '1', '0', '0' };
    const char let_line_data_2[] = { ST_IMPL_LET, 'X' | EOT, '=', '1', '0', '0' };
    const char if_line_data_1[] = { ST_IF_THEN, 'X' | EOT, TOKEN_OP | OP_EQ, '1', TOKEN_CLAUSE | CLAUSE_THEN, ST_GOTO, '1', '0',};
    const char input_line_data_1[] = { ST_INPUT, 'A' | EOT };
    const char input_line_data_2[] = { ST_INPUT, 'A' | EOT, ',', 'B' | EOT, ',', 'C' | EOT };
    const char on_line_data_1[] = { ST_ON, '1', TOKEN_CLAUSE | CLAUSE_GOTO, '1', '0' };
    const char on_line_data_2[] = { ST_ON, '1', TOKEN_CLAUSE | CLAUSE_GOSUB, '1', '0' };
    const char on_line_data_3[] = { ST_ON, 'X' | EOT, TOKEN_CLAUSE | CLAUSE_GOSUB, '1', '0', ',', '2', '0', ',', '3', '0' };
    const char list_line_data_1[] = { ST_LIST };
    const char list_line_data_2[] = { ST_LIST, '1', '0', '0' };
    const char list_line_data_3[] = { ST_LIST, '1', '0', '0', ',', '5', '0', '0' };
    const char data_line_data_1[] = { ST_DATA, 'H', 'E', 'L', 'L', 'O', ',', '\"', 'X', ',', 'Y', '\"', ',', '5' };
    const char poke_line_data_1[] = { ST_POKE, '7', '1', '0', ',', '0' };
    const char dim_line_data_1[] = { ST_DIM, 'A' | EOT, '(', '5', ')'  };
    const char extension_line_data_1[] = { TOKEN_EXTENSION | 0 };

    PRINT_TEST_NAME();

    // Simple statement
    call_parse_pvm("END", pvm_statement, simple_line_data_1, sizeof simple_line_data_1, __LINE__);

    // PRINT
    call_parse_pvm("PRINT 1", pvm_statement, print_line_data_1, sizeof print_line_data_1, __LINE__);
    call_parse_pvm("PRINT 1,\"YES\";(0)", pvm_statement, print_line_data_2, sizeof print_line_data_2, __LINE__);

    // FOR
    call_parse_pvm("FOR X=1 TO 5", pvm_statement, for_line_data_1, sizeof for_line_data_1, __LINE__);
    call_parse_pvm("FOR X=1 TO 20 STEP 2", pvm_statement, for_line_data_2, sizeof for_line_data_2, __LINE__);

    // NEXT
    call_parse_pvm("NEXT X", pvm_statement, next_line_data_1, sizeof next_line_data_1, __LINE__);

    // LET
    call_parse_pvm("LET X=100", pvm_statement, let_line_data_1, sizeof let_line_data_1, __LINE__);
    call_parse_pvm("X=100", pvm_statement, let_line_data_2, sizeof let_line_data_2, __LINE__);

    // IF
    call_parse_pvm("IF X=1 THEN GOTO 10", pvm_statement, if_line_data_1, sizeof if_line_data_1, __LINE__);

    // INPUT (covers READ)
    call_parse_pvm("INPUT A", pvm_statement, input_line_data_1, sizeof input_line_data_1, __LINE__);
    call_parse_pvm("INPUT A,B,C", pvm_statement, input_line_data_2, sizeof input_line_data_2, __LINE__);

    // ON
    call_parse_pvm("ON 1 GOTO 10", pvm_statement, on_line_data_1, sizeof on_line_data_1, __LINE__);
    call_parse_pvm("ON 1 GOSUB 10", pvm_statement, on_line_data_2, sizeof on_line_data_2, __LINE__);
    call_parse_pvm("ON X GOSUB 10,20,30", pvm_statement, on_line_data_3, sizeof on_line_data_3, __LINE__);

    // LIST
    call_parse_pvm("LIST", pvm_statement, list_line_data_1, sizeof list_line_data_1, __LINE__);
    call_parse_pvm("LIST 100", pvm_statement, list_line_data_2, sizeof list_line_data_2, __LINE__);
    call_parse_pvm("LIST 100,500", pvm_statement, list_line_data_3, sizeof list_line_data_3, __LINE__);

    // DATA
    call_parse_pvm("DATA HELLO,\"X,Y\",5", pvm_statement, data_line_data_1, sizeof data_line_data_1, __LINE__);

    // POKE
    call_parse_pvm("POKE 710, 0", pvm_statement, poke_line_data_1, sizeof poke_line_data_1, __LINE__);

    // DIM
    call_parse_pvm("DIM A(5)", pvm_statement, dim_line_data_1, sizeof dim_line_data_1, __LINE__);

    // BYE (extension statement)
    call_parse_pvm("BYE", pvm_statement, extension_line_data_1, sizeof extension_line_data_1, __LINE__);
}

void call_parse_line(const char* s, const Line* expect_line, int line) {
    fprintf(stderr, "  %s:%d: parse_line(\"%s\")\n", __FILE__, line, s);
    strcpy(buffer, s);
    parse_line();
    ASSERT_EQ(err, 0);
    ASSERT_EQ(buffer_pos, strlen(s));
    ASSERT_MEMORY_EQ(&line_buffer, expect_line, expect_line->next_line_offset);
    ASSERT_EQ(line_pos, expect_line->next_line_offset);
}

void test_parse_line(void) {

    const Line line_1 = { 6, -1, { 6, ST_POP, 0 } };
    const Line line_2 = { 9, -1, { 6, ST_POP, 0, 9, ST_POP, 0 } };
    const Line line_3 = { 11, -1, { 11, ST_LET, 'X' | EOT, '=', '1', '0', '0', 0 } };
    const Line line_4 = { 15, -1, { 11, ST_LET, 'X' | EOT, '=', '1', '0', '0', 0, 15, ST_PRINT, 'X' | EOT, 0 } };
    const Line line_5 = { 7, 10, { 7, ST_PRINT, '1', 0 } };

    PRINT_TEST_NAME();

    call_parse_line("POP", &line_1, __LINE__);
    call_parse_line("POP:POP", &line_2, __LINE__);
    call_parse_line("LET X=100", &line_3, __LINE__);
    call_parse_line("LET X=100:PRINT X", &line_4, __LINE__);
    call_parse_line("10 PRINT 1", &line_5, __LINE__);
}

int main(void) {
    initialize_target();
    test_pvm_number();
    test_pvm_string();
    test_pvm_name();
    test_pvm_expression();
    test_pvm_statement();
    test_parse_line();
    return 0;
}