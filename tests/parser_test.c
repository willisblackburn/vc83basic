#include "test.h"

void call_parse_name(const char* s, char set_buffer_pos, const char* expect_line_data, size_t expect_line_data_size,
        char expect_buffer_pos, int line) {
    fprintf(stderr, "  %s:%d: parse_name(\"%s\")\n", __FILE__, line, s);
    strcpy(buffer, s);
    buffer_pos = set_buffer_pos;
    line_pos = offsetof(Line, data);
    parse_name();
    ASSERT_EQ(err, 0);
    ASSERT_PTR_EQ(decode_name_ptr, line_buffer.data);
    ASSERT_MEMORY_EQ(line_buffer.data, expect_line_data, expect_line_data_size);
    ASSERT_EQ(buffer_pos, expect_buffer_pos);
}

void test_parse_name(void) {

    const char print_line_data[] = { 'P', 'R', 'I', 'N', 'T' | EOT };
    const char printx_line_data[] = { 'P', 'R', 'I', 'N', 'T', 'X' | EOT };
    const char print10_line_data[] = { 'P', 'R', 'I', 'N', 'T', '1', '0' | EOT };
    const char print10x_line_data[] = { 'P', 'R', 'I', 'N', 'T', '1', '0', 'X' | EOT };
    const char x_line_data[] = { 'X' | EOT  };
    const char goto_line_data[] = { 'G', 'O', 'T', 'O' | EOT  };

    PRINT_TEST_NAME();

    call_parse_name("PRINT", 0, print_line_data, sizeof print_line_data, 5, __LINE__);

    // Start at the space to verify that it skips whitespace.
    call_parse_name("10 PRINT", 2, print_line_data, sizeof print_line_data, 8, __LINE__);

    call_parse_name("10 PRINT X", 3, print_line_data, sizeof print_line_data, 8, __LINE__);

    call_parse_name("10 PRINTX", 3, printx_line_data, sizeof printx_line_data, 9, __LINE__);

    call_parse_name("10 PRINT10", 3, print10_line_data, sizeof print10_line_data, 10, __LINE__);

    call_parse_name("10 PRINT10X", 3, print10x_line_data, sizeof print10x_line_data, 11, __LINE__);

    // Start parse at space.
    call_parse_name("ON X/2 GOTO 10,20", 2, x_line_data, sizeof x_line_data, 4, __LINE__);
    call_parse_name("ON X/2 GOTO 10,20", 6, goto_line_data, sizeof goto_line_data, 11, __LINE__);

    // Digits are not names.
    strcpy(buffer, "10");
    buffer_pos = 0;
    parse_name();
    ASSERT_NE(err, 0);
    ASSERT_EQ(buffer_pos, 0);

    // buffer_pos will reflect skipped whitespace even if parse fails.
    strcpy(buffer, "  ");
    buffer_pos = 0;
    parse_name();
    ASSERT_NE(err, 0);
    ASSERT_EQ(buffer_pos, 2);

    strcpy(buffer, "");
    buffer_pos = 0;
    parse_name();
    ASSERT_NE(err, 0);
    ASSERT_EQ(buffer_pos, 0);
}

void call_parse_number(const char* s, char set_buffer_pos, const char* expect_line_data, size_t expect_line_data_size,
        char expect_buffer_pos, int line) {
    fprintf(stderr, "  %s:%d: parse_number(\"%s\")\n", __FILE__, line, s);
    strcpy(buffer, s);
    buffer_pos = set_buffer_pos;
    line_pos = offsetof(Line, data);
    parse_number();
    ASSERT_EQ(err, 0);
    ASSERT_PTR_EQ(decode_name_ptr, line_buffer.data);
    ASSERT_MEMORY_EQ(line_buffer.data, expect_line_data, expect_line_data_size);
    ASSERT_EQ(buffer_pos, expect_buffer_pos);
}

void test_parse_number(void) {

    const char number_10_line_data[] = { '1', '0' };
    const char number_20_line_data[] = { '2', '0' };

    PRINT_TEST_NAME();

    call_parse_number("10 PRINT X", 0, number_10_line_data, sizeof number_10_line_data, 2, __LINE__);

    // The function should honor the current read position.
    call_parse_number("1020 PRINT X", 2, number_20_line_data, sizeof number_20_line_data, 4, __LINE__);

    // The function should return carry set if an invalid number.
    strcpy(buffer, "invalid");
    buffer_pos = 0;
    parse_number();
    ASSERT_NE(err, 0);
    ASSERT_EQ(buffer_pos, 0);

    strcpy(buffer, "");
    buffer_pos = 0;
    parse_number();
    ASSERT_NE(err, 0);
    ASSERT_EQ(buffer_pos, 0);
}

void call_parse_expression(const char* s, const char* expect_line_data, size_t expect_line_data_size, int line) {
    size_t expect_buffer_pos;
    fprintf(stderr, "  %s:%d: parse_expression(\"%s\")\n", __FILE__, line, s);
    expect_buffer_pos = strlen(s);
    strcpy(buffer, s);
    buffer_pos = 0;
    line_pos = offsetof(Line, data);
    parse_expression();
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, expect_line_data, expect_line_data_size);
    ASSERT_EQ(buffer_pos, expect_buffer_pos);
    ASSERT_EQ(line_pos, offsetof(Line, data) + expect_line_data_size);
}

void test_parse_expression(void) {
    
    const char line_data_1[] = { '1' };
    const char line_data_2[] = { 'X' | EOT };
    const char line_data_3[] = { 'X' | EOT, TOKEN_OP | OP_ADD, '1' };
    const char line_data_4[] = { '(', 'X' | EOT, TOKEN_OP | OP_ADD, '3', ')',
        TOKEN_OP | OP_MUL, 'Y' | EOT };
    const char line_data_5[] = { TOKEN_UNARY_OP | UNARY_OP_MINUS, 'X' | EOT };

    PRINT_TEST_NAME();

    initialize_program();

    call_parse_expression("1", line_data_1, sizeof line_data_1, __LINE__);
    call_parse_expression("X", line_data_2, sizeof line_data_2, __LINE__);
    call_parse_expression("X+1", line_data_3, sizeof line_data_3, __LINE__);
    call_parse_expression("(X+3)*Y", line_data_4, sizeof line_data_4, __LINE__);
    call_parse_expression("-X", line_data_5, sizeof line_data_5, __LINE__);
}

void test_parse_argument_separator(void) {

    PRINT_TEST_NAME();

    strcpy(buffer, ",");
    buffer_pos = 0;
    parse_argument_separator();
    ASSERT_NE(err, 0);
    ASSERT_EQ(buffer_pos, 1);

    strcpy(buffer, "  ,");
    buffer_pos = 0;
    parse_argument_separator();
    ASSERT_NE(err, 0);
    ASSERT_EQ(buffer_pos, 3);

    strcpy(buffer, "x");
    buffer_pos = 0;
    parse_argument_separator();
    ASSERT_EQ(err, 0);
    ASSERT_EQ(buffer_pos, 0);

    strcpy(buffer, ",");
    buffer_pos = 1;
    parse_argument_separator();
    ASSERT_EQ(err, 0);
    ASSERT_EQ(buffer_pos, 1);
}

void call_parse_argument_list(const char* s, char count, const char* expect_line_data, size_t expect_line_data_length, 
        char expect_remaining, int line) {
    size_t expect_buffer_pos;
    char remaining;
    fprintf(stderr, "  %s:%d: parse_argument_list(\"%s\", %d)\n", __FILE__, line, s, count);
    expect_buffer_pos = strlen(s);
    strcpy(buffer, s);
    buffer_pos = 0;
    line_pos = offsetof(Line, data);
    remaining = parse_argument_list(count);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(buffer_pos, expect_buffer_pos);
    ASSERT_MEMORY_EQ(line_buffer.data, expect_line_data, expect_line_data_length);
    ASSERT_EQ(line_pos, offsetof(Line, data) + expect_line_data_length);
    ASSERT_EQ(remaining, expect_remaining);
}

void test_parse_argument_list(void) {

    const char line_data_1[] = { '1', ',', 'X' | EOT };
    const char line_data_2[] = { '1' };

    PRINT_TEST_NAME();

    call_parse_argument_list("1,X", 2, line_data_1, sizeof line_data_1, 0, __LINE__);
    call_parse_argument_list("1", 1, line_data_2, sizeof line_data_2, 0, __LINE__);
    call_parse_argument_list("1,X", 1, line_data_1, sizeof line_data_1, -1, __LINE__);
    call_parse_argument_list("1", 2, line_data_2, sizeof line_data_2, 1, __LINE__);
    call_parse_argument_list("", 1, NULL, 0, 1, __LINE__);
}

void call_parse_directive(const char* s, char directive, const char* expect_line_data, size_t expect_line_data_length, 
        int line) {
    size_t expect_buffer_pos;
    fprintf(stderr, "  %s:%d: parse_directive(\"%s\", %d)\n", __FILE__, line, s, directive);
    expect_buffer_pos = strlen(s);
    strcpy(buffer, s);
    buffer_pos = 0;
    line_pos = offsetof(Line, data);
    parse_directive(directive);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(buffer_pos, expect_buffer_pos);
    ASSERT_MEMORY_EQ(line_buffer.data, expect_line_data, expect_line_data_length);
    ASSERT_EQ(line_pos, offsetof(Line, data) + expect_line_data_length);
}

void test_parse_directive(void) {

    const char line_data_1[] = { '1' };
    const char line_data_2[] = { 'X' | EOT };
    const char line_data_3[] = { 'X' | EOT, ',', 'Y' | EOT };

    PRINT_TEST_NAME();

    initialize_program();

    call_parse_directive("1", 1, line_data_1, sizeof line_data_1, __LINE__);
    call_parse_directive("X", 1, line_data_2, sizeof line_data_2, __LINE__);
    call_parse_directive("X", NT_VAR, line_data_2, sizeof line_data_2, __LINE__);
    call_parse_directive("X", NT_RPT_VAR, line_data_2, sizeof line_data_2, __LINE__);
    call_parse_directive("X,Y", NT_RPT_VAR, line_data_3, sizeof line_data_3, __LINE__);
}

void call_parse_statement(const char* s, const char* expect_line_data, size_t expect_line_data_length, int line) {
    size_t expect_buffer_pos;
    fprintf(stderr, "  %s:%d: parse_statement(\"%s\")\n", __FILE__, line, s);
    expect_buffer_pos = strlen(s);
    strcpy(buffer, s);
    buffer_pos = 0;
    line_pos = offsetof(Line, data);
    parse_statement();
    ASSERT_EQ(err, 0);
    ASSERT_EQ(buffer_pos, expect_buffer_pos);
    ASSERT_MEMORY_EQ(line_buffer.data, expect_line_data, expect_line_data_length);
    ASSERT_EQ(line_pos, offsetof(Line, data) + expect_line_data_length);
}

void test_parse_statement(void) {

    const char line_data_1[] = { ST_RUN };
    const char line_data_2[] = { ST_PRINT, '8', 0 };
    const char line_data_3[] = { ST_LET, 'X' | EOT, 0, '1', '0', '0', 0 };
    const char line_data_4[] = { ST_INPUT, 'X' | EOT, ',', 'Y' | EOT, 0 };
    const char line_data_5[] = { ST_LIST, '1', '0', ',', '2', '0', 0 };
    const char line_data_6[] = { ST_PRINT, '(', 'X' | EOT, TOKEN_OP | OP_ADD, '3', ')',
        TOKEN_OP | OP_MUL, 'Y' | EOT, 0 };

    PRINT_TEST_NAME();

    initialize_program();

    call_parse_statement("RUN", line_data_1, sizeof line_data_1, __LINE__);
    call_parse_statement("PRINT 8", line_data_2, sizeof line_data_2, __LINE__);
    call_parse_statement("LET X=100", line_data_3, sizeof line_data_3, __LINE__);
    call_parse_statement("INPUT X,Y", line_data_4, sizeof line_data_4, __LINE__);
    call_parse_statement("LIST 10,20", line_data_5, sizeof line_data_5, __LINE__);
    call_parse_statement("PRINT (X+3)*Y", line_data_6, sizeof line_data_6, __LINE__);

    // Test that adding spaces here and there doesn't mix up the parser.

    call_parse_statement("PRINT    8", line_data_2, sizeof line_data_2, __LINE__);
    call_parse_statement("PRINT 8  ", line_data_2, sizeof line_data_2, __LINE__);
    call_parse_statement("LET   X  =  100  ", line_data_3, sizeof line_data_3, __LINE__);

    // Make sure the parser doesn't keep parsing past the end of the name table record.
    // Note the parser will skip the space after 8; that's okay.

    strcpy(buffer, "PRINT 8 9");
    buffer_pos = 0;
    line_pos = offsetof(Line, data);
    parse_statement();
    ASSERT_EQ(err, 0);
    ASSERT_EQ(buffer_pos, 8);
    ASSERT_EQ(line_pos, offsetof(Line, data) + sizeof line_data_2);

    // Make sure the parser doesn't match continued names.

    strcpy(buffer, "PRINTX");
    buffer_pos = 0;
    line_pos = offsetof(Line, data);
    parse_statement();
    ASSERT_NE(err, 0);
    ASSERT_EQ(buffer_pos, 0);
}

void test_parse_line(void) {

    const char line_data_1[] = { ST_LET, 'X' | EOT, 0, '1', '0', '0', 0 };
    const char line_data_2[] = { ST_RUN };

    PRINT_TEST_NAME();

    initialize_program();

    // Happy path with line number

    strcpy(buffer, "10 LET X=100");
    parse_line();
    ASSERT_EQ(err, 0);
    ASSERT_EQ(line_buffer.next_line_offset, offsetof(Line, data) + sizeof line_data_1);
    ASSERT_EQ(line_buffer.number, 10);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_1, sizeof line_data_1);

    // Happy path immediate mode

    strcpy(buffer, "RUN");
    parse_line();
    ASSERT_EQ(err, 0);
    ASSERT_EQ(line_buffer.next_line_offset,  offsetof(Line, data) + sizeof line_data_2);
    ASSERT_EQ(line_buffer.number, -1);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_2, sizeof line_data_2);

    // Empty line

    strcpy(buffer, "");
    parse_line();
    ASSERT_EQ(err, 0);
    strcpy(buffer, "  ");
    parse_line();
    ASSERT_EQ(err, 0);

    // Test that the parser rejects statements that continue past the point where they're supposed to end.

    strcpy(buffer, "LET X=100,5");
    parse_line();
    ASSERT_NE(err, 0);
}

int main(void) {
    initialize_target();
    test_parse_name();
    test_parse_number();
    test_parse_expression();
    test_parse_argument_separator();
    test_parse_argument_list();
    test_parse_directive();
    test_parse_statement();
    test_parse_line();
    return 0;
}