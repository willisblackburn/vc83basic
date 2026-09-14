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
    read_ptr = buffer;
    line_pos = offsetof(Line, data);
    parse_pvm(start);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(buffer_pos, expect_buffer_pos);
    ASSERT_MEMORY_EQ(line_buffer.data, expect_line_data, expect_line_data_length);
    ASSERT_EQ(line_pos, offsetof(Line, data) + expect_line_data_length);
}

void call_parse_pvm(const char* s, const char* start, const char* expect_line_data,
    size_t expect_line_data_length, int line) {
    call_parse_pvm_expect_buffer_pos(s, start, expect_line_data, expect_line_data_length, strlen(s), line);
}

void test_pvm_expression(void) {

    const char constant_line_data_1[] = { TOK_NUM, '1' | EOT };
    const char variable_line_data_1[] = { TOK_NAME, 'X' | EOT };
    const char variable_line_data_2[] = { TOK_NAME, 'S', '$' | EOT };
    const char variable_line_data_3[] = { TOK_NAME, 'X' | EOT, TOK_LPAREN, TOK_NUM, '5' | EOT, TOK_RPAREN };
    const char variable_line_data_4[] = { TOK_NAME, 'S', '$' | EOT, TOK_LPAREN, TOK_NUM, '1' | EOT, TOK_COMMA, TOK_NUM, '2', '5' | EOT, TOK_RPAREN  };
    const char operator_line_data_1[] = { TOK_NUM, '1' | EOT, TOK_ADD, TOK_NUM, '1' | EOT };
    const char operator_line_data_2[] = { TOK_NUM, '1' | EOT, TOK_ADD, TOK_NUM, '1' | EOT, TOK_DIV, TOK_NUM, '2' | EOT };
    const char operator_line_data_3[] = { TOK_STRING, 1, 'A', '"' | EOT, TOK_CONCAT, TOK_STRING, 1, 'B', '"' | EOT };
    const char operator_line_data_4[] = { TOK_NAME, 'X' | EOT, TOK_AND, TOK_NAME, 'Y' | EOT };
    const char unary_operator_line_data_1[] = { TOK_NUM, '1' | EOT, TOK_ADD, TOK_SUB, TOK_NAME, 'A' | EOT };
    const char unary_operator_line_data_2[] = { TOK_NOT, TOK_NUM, '1' | EOT };
    const char parens_line_data_1[] = { TOK_NUM, '1' | EOT, TOK_ADD, TOK_LPAREN, TOK_NUM, '1' | EOT, TOK_ADD, TOK_NUM, '1' | EOT, TOK_RPAREN };
    const char parens_line_data_2[] = { TOK_NAME, 'X' | EOT, TOK_AND, TOK_LPAREN, TOK_NAME, 'Y' | EOT, TOK_OR, TOK_NOT, TOK_NAME, 'Z' | EOT, TOK_RPAREN };
    const char function_line_data_1[] = { TOK_LEN, TOK_LPAREN, TOK_STRING, 5, 'H', 'E', 'L', 'L', 'O', '"' | EOT, TOK_RPAREN };
    const char function_line_data_2[] = { TOK_MID_S, TOK_LPAREN, TOK_STRING, 5, 'H', 'E', 'L', 'L', 'O', '"' | EOT, TOK_COMMA, TOK_NUM, '2' | EOT, TOK_COMMA, TOK_NUM, '3' | EOT, TOK_RPAREN };
    const char function_line_data_3[] = { TOK_VER_S, TOK_LPAREN, TOK_RPAREN };

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
    call_parse_pvm("VER$()", pvm_expression, function_line_data_3, sizeof function_line_data_3, __LINE__);
}

void test_pvm_statement(void) {

    const char simple_line_data_1[] = { TOK_END };
    const char print_line_data_1[] = { TOK_PRINT, TOK_NUM, '1' | EOT };
    const char print_line_data_2[] = { TOK_PRINT, TOK_NUM, '1' | EOT, TOK_COMMA, TOK_STRING, 3, 'Y', 'E', 'S', '"' | EOT, TOK_SEMI, TOK_LPAREN, TOK_NUM, '0' | EOT, TOK_RPAREN };
    const char print_line_data_3[] = { TOK_ALT_PRINT, TOK_NAME, 'X' | EOT };
    const char for_line_data_1[] = { TOK_FOR, TOK_NAME, 'X' | EOT, TOK_EQ, TOK_NUM, '1' | EOT, TOK_TO, TOK_NUM, '5' | EOT };
    const char for_line_data_2[] = { TOK_FOR, TOK_NAME, 'X' | EOT, TOK_EQ, TOK_NUM, '1' | EOT, TOK_TO, TOK_NUM, '2', '0' | EOT, TOK_STEP, TOK_NUM, '2' | EOT };
    const char next_line_data_1[] = { TOK_NEXT, TOK_NAME, 'X' | EOT };
    const char let_line_data_1[] = { TOK_LET, TOK_NAME, 'X' | EOT, TOK_EQ, TOK_NUM, '1', '0', '0' | EOT };
    const char let_line_data_2[] = { TOK_NAME, 'X' | EOT, TOK_EQ, TOK_NUM, '1', '0', '0' | EOT };
    const char if_line_data_1[] = { TOK_IF, TOK_NAME, 'X' | EOT, TOK_EQ, TOK_NUM, '1' | EOT, TOK_THEN, TOK_GOTO, TOK_NUM, '1', '0' | EOT };
    const char if_line_data_2[] = { TOK_IF, TOK_NAME, 'X' | EOT, TOK_EQ, TOK_NUM, '1' | EOT, TOK_THEN, TOK_NUM, '1', '0' | EOT };
    const char if_line_data_3[] = { TOK_IF, TOK_NAME, 'X' | EOT, TOK_EQ, TOK_NUM, '1' | EOT, TOK_THEN, TOK_LET, TOK_NAME, 'X' | EOT, TOK_EQ, TOK_NAME, 'X' | EOT, TOK_ADD, TOK_NUM, '1' | EOT };
    const char if_line_data_4[] = { TOK_IF, TOK_NAME, 'X' | EOT, TOK_EQ, TOK_NUM, '1' | EOT, TOK_THEN, TOK_NAME, 'X' | EOT, TOK_EQ, TOK_NAME, 'X' | EOT, TOK_ADD, TOK_NUM, '1' | EOT };
    const char input_line_data_1[] = { TOK_INPUT, TOK_NAME, 'A' | EOT };
    const char input_line_data_2[] = { TOK_INPUT, TOK_NAME, 'A' | EOT, TOK_COMMA, TOK_NAME, 'B' | EOT, TOK_COMMA, TOK_NAME, 'C' | EOT };
    const char on_line_data_1[] = { TOK_ON, TOK_NUM, '1' | EOT, TOK_GOTO, TOK_NUM, '1', '0' | EOT };
    const char on_line_data_2[] = { TOK_ON, TOK_NUM, '1' | EOT, TOK_GOSUB, TOK_NUM, '1', '0' | EOT };
    const char on_line_data_3[] = { TOK_ON, TOK_NAME, 'X' | EOT, TOK_GOSUB, TOK_NUM, '1', '0' | EOT, TOK_COMMA, TOK_NUM, '2', '0' | EOT, TOK_COMMA, TOK_NUM, '3', '0' | EOT };
    const char list_line_data_1[] = { TOK_LIST };
    const char list_line_data_2[] = { TOK_LIST, TOK_NUM, '1', '0', '0' | EOT };
    const char list_line_data_3[] = { TOK_LIST, TOK_NUM, '1', '0', '0' | EOT, TOK_COMMA, TOK_NUM, '5', '0', '0' | EOT };
    const char data_line_data_1[] = { TOK_DATA, 'H', 'E', 'L', 'L', 'O', ',', '\"', 'X', ',', 'Y', '\"', ',', '5' };
    const char rem_line_data_1[] = { TOK_REM, 'T', 'H', 'I', 'S', ' ', 'I', 'S', ' ', 'A', ' ', 'R', 'E', 'M' };
    const char poke_line_data_1[] = { TOK_POKE, TOK_NUM, '7', '1', '0' | EOT, TOK_COMMA, TOK_NUM, '0' | EOT };
    const char dim_line_data_1[] = { TOK_DIM, TOK_NAME, 'A' | EOT, TOK_LPAREN, TOK_NUM, '5' | EOT, TOK_RPAREN };
    const char extension_line_data_1[] = { TOK_BYE | 0 };

    PRINT_TEST_NAME();

    // Simple statement
    call_parse_pvm("END", pvm_statement, simple_line_data_1, sizeof simple_line_data_1, __LINE__);

    // PRINT
    call_parse_pvm("PRINT 1", pvm_statement, print_line_data_1, sizeof print_line_data_1, __LINE__);
    call_parse_pvm("PRINT 1,\"YES\";(0)", pvm_statement, print_line_data_2, sizeof print_line_data_2, __LINE__);
    call_parse_pvm("?X", pvm_statement, print_line_data_3, sizeof print_line_data_3, __LINE__);
    call_parse_pvm("? X", pvm_statement, print_line_data_3, sizeof print_line_data_3, __LINE__);

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
    call_parse_pvm("IF X=1 THEN 10", pvm_statement, if_line_data_2, sizeof if_line_data_2, __LINE__);
    call_parse_pvm("IF X=1 THEN LET X=X+1", pvm_statement, if_line_data_3, sizeof if_line_data_3, __LINE__);
    call_parse_pvm("IF X=1 THEN X=X+1", pvm_statement, if_line_data_4, sizeof if_line_data_4, __LINE__);

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

    // DATA & REM
    call_parse_pvm("DATA HELLO,\"X,Y\",5", pvm_statement, data_line_data_1, sizeof data_line_data_1, __LINE__);
    call_parse_pvm("REM THIS IS A REM", pvm_statement, rem_line_data_1, sizeof rem_line_data_1, __LINE__);

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

void call_parse_blank_line(const char* s, int expect_line_number, int line) {
    fprintf(stderr, "  %s:%d: parse_line(\"%s\")\n", __FILE__, line, s);
    strcpy(buffer, s);
    parse_line();
    ASSERT_EQ(err, 0);
    ASSERT_EQ(buffer_pos, strlen(s));
    // parse_line reserves byte for first next statement offset even if there's no statement.
    ASSERT_EQ(line_buffer.next_line_offset, sizeof(Line) + 1);
    ASSERT_EQ(line_buffer.number, expect_line_number);
    ASSERT_EQ(line_pos, sizeof(Line) + 1);
}

void test_parse_line(void) {

    const Line line_1 = { 6, -1, { 6, TOK_POP, TOK_EOL } };
    const Line line_2 = { 9, -1, { 6, TOK_POP, TOK_EOL, 9, TOK_POP, TOK_EOL } };
    const Line line_3 = { 13, -1, { 13, TOK_LET, TOK_NAME, 'X' | EOT, TOK_EQ, TOK_NUM, '1', '0', '0' | EOT, TOK_EOL } };
    const Line line_4 = { 18, -1, { 13, TOK_LET, TOK_NAME, 'X' | EOT, TOK_EQ, TOK_NUM, '1', '0', '0' | EOT, TOK_EOL, 18, TOK_PRINT, TOK_NAME, 'X' | EOT, TOK_EOL } };
    const Line line_5 = { 8, 10, { 8, TOK_PRINT, TOK_NUM, '1' | EOT, TOK_EOL } };

    PRINT_TEST_NAME();

    call_parse_line("POP", &line_1, __LINE__);
    call_parse_line("POP:POP", &line_2, __LINE__);
    call_parse_line("LET X=100", &line_3, __LINE__);
    call_parse_line("LET X=100:PRINT X", &line_4, __LINE__);
    call_parse_line("10 PRINT 1", &line_5, __LINE__);

    call_parse_blank_line("", -1, __LINE__);
    call_parse_blank_line("   ", -1, __LINE__);
    call_parse_blank_line("10", 10, __LINE__);
    call_parse_blank_line("10   ", 10, __LINE__);
}

void test_max_line_length(void) {
    char buf[256];
    int pos;
    int i;

    PRINT_TEST_NAME();

    // Long valid line (REM statement fitting in line_buffer)
    memset(buf, 'X', 230);
    buf[230] = '\0';
    sprintf(buffer, "10 REM %s", buf);
    parse_line();
    ASSERT_EQ(err, 0);
    ASSERT_EQ(line_buffer.number, 10);

    // Long expression that exceeds MAX_LINE_LENGTH
    memset(buf, 0, sizeof buf);
    strcpy(buf, "10 PRINT ");
    pos = strlen(buf);
    while (pos < 240) {
        strcpy(buf + pos, "1+");
        pos += 2;
    }
    buf[pos] = '1';
    buf[pos + 1] = '\0';

    strcpy(buffer, buf);
    parse_line();
    ASSERT_EQ(err, ERR_LINE_TOO_LONG);

    // Many chained statements that exceed MAX_LINE_LENGTH
    pos = 0;
    strcpy(buf, "10 ");
    pos = 3;
    for (i = 0; i < 35; ++i) {
        strcpy(buf + pos, "X=1:");
        pos += 4;
    }
    buf[pos] = '\0';
    // Make sure we didn't clobber stack...
    ASSERT(pos < 256);
    strcpy(buffer, buf);
    parse_line();
    ASSERT_EQ(err, ERR_LINE_TOO_LONG);
}

int main(void) {
    initialize_target();
    test_pvm_expression();
    test_pvm_statement();
    test_parse_line();
    test_max_line_length();
    return 0;
}