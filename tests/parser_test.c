#include "test.h"

void test_is_name_character(void) {

    PRINT_TEST_NAME();

    is_name_character('A');
    ASSERT_EQ(err, 0);
    is_name_character('Z');
    ASSERT_EQ(err, 0);
    is_name_character('0');
    ASSERT_EQ(err, 0);
    is_name_character('9');
    ASSERT_EQ(err, 0);
    is_name_character('_');
    ASSERT_EQ(err, 0);

    is_name_character('?');
    ASSERT_NE(err, 0);
    is_name_character('=');
    ASSERT_NE(err, 0);
    is_name_character('#');
    ASSERT_NE(err, 0);
    is_name_character('%');
    ASSERT_NE(err, 0);
    is_name_character('@');
    ASSERT_NE(err, 0);
    is_name_character('[');
    ASSERT_NE(err, 0);
    is_name_character('/');
    ASSERT_NE(err, 0);
    is_name_character(':');
    ASSERT_NE(err, 0);
    is_name_character(' ');
    ASSERT_NE(err, 0);
    is_name_character(0);
    ASSERT_NE(err, 0);
    is_name_character(0x7F);
    ASSERT_NE(err, 0);
    is_name_character(0x80);
    ASSERT_NE(err, 0);
    is_name_character(0xFF);
    ASSERT_NE(err, 0);
}

 void call_parse_name(const char* s, char set_buffer_pos, const char* expect_line_data, size_t expect_line_data_size,
        char expect_name_length, char expect_buffer_pos, int line) {
    fprintf(stderr, "  %s:%d: parse_name(\"%s\")\n", __FILE__, line, s);
    strcpy(buffer, s);
    buffer_pos = set_buffer_pos;
    line_pos = offsetof(Line, data);
    parse_name();
    ASSERT_EQ(err, 0);
    ASSERT_PTR_EQ(name_ptr, line_buffer.data);
    ASSERT_EQ(name_length, expect_name_length);
    ASSERT_MEMORY_EQ(line_buffer.data, expect_line_data, expect_line_data_size);
    ASSERT_EQ(buffer_pos, expect_buffer_pos);
}

void test_parse_name(void) {

    const char print_line_data[] = { 'P', 'R', 'I', 'N', 'T' | NT_STOP };
    const char printx_line_data[] = { 'P', 'R', 'I', 'N', 'T', 'X' | NT_STOP };
    const char print10_line_data[] = { 'P', 'R', 'I', 'N', 'T', '1', '0' | NT_STOP };
    const char print10x_line_data[] = { 'P', 'R', 'I', 'N', 'T', '1', '0', 'X' | NT_STOP };
    const char x_line_data[] = { 'X' | NT_STOP  };
    const char goto_line_data[] = { 'G', 'O', 'T', 'O' | NT_STOP  };
    const char digits_line_data[] = { '1', '0' | NT_STOP };

    PRINT_TEST_NAME();

    call_parse_name("PRINT", 0, print_line_data, sizeof print_line_data, 5, 5, __LINE__);

    // Start at the space to verify that it skips whitespace.
    call_parse_name("10 PRINT", 2, print_line_data, sizeof print_line_data, 5, 8, __LINE__);

    call_parse_name("10 PRINT X", 3, print_line_data, sizeof print_line_data, 5, 8, __LINE__);

    call_parse_name("10 PRINTX", 3, printx_line_data, sizeof printx_line_data, 6, 9, __LINE__);

    call_parse_name("10 PRINT10", 3, print10_line_data, sizeof print10_line_data, 7, 10, __LINE__);

    call_parse_name("10 PRINT10X", 3, print10x_line_data, sizeof print10x_line_data, 8, 11, __LINE__);

    // Start parse at space.
    call_parse_name("ON X/2 GOTO 10,20", 2, x_line_data, sizeof x_line_data, 1, 4, __LINE__);
    call_parse_name("ON X/2 GOTO 10,20", 6, goto_line_data, sizeof goto_line_data, 4, 11, __LINE__);

    // Digits are names; this is okay because we try to parse numbers before names.
    call_parse_name("10", 0, digits_line_data, sizeof digits_line_data, 2, 2, __LINE__);

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

void test_char_to_digit(void) {
    char d;

    PRINT_TEST_NAME();

    d = char_to_digit('0');
    ASSERT_EQ(err, 0);
    ASSERT_EQ(d, 0);
    d = char_to_digit('9');
    ASSERT_EQ(err, 0);
    ASSERT_EQ(d, 9);
    char_to_digit('0'-1);
    ASSERT_NE(err, 0);
    char_to_digit('9'+1);
    ASSERT_NE(err, 0);
    char_to_digit(' ');
    ASSERT_NE(err, 0);
    char_to_digit('A');
    ASSERT_NE(err, 0);
    char_to_digit(0);
    ASSERT_NE(err, 0);
    char_to_digit(255);
    ASSERT_NE(err, 0);
}

int call_read_number(const char* s, char set_buffer_pos) {
    strcpy(buffer, s);
    buffer_pos = set_buffer_pos;
    return read_number();
}

void test_read_number(void) {
    int number;

    PRINT_TEST_NAME();

    number = call_read_number("10 PRINT X", 0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(number, 10);
    ASSERT_EQ(buffer_pos, 2);

    // The function should honor the current read position.
    number = call_read_number("1020 PRINT X", 2);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(number, 20);
    ASSERT_EQ(buffer_pos, 4);

    // The function should return carry set if an invalid number.
    call_read_number("invalid", 0);
    ASSERT_NE(err, 0);
    ASSERT_EQ(buffer_pos, 0);

    call_read_number("", 0);
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
    
    const char line_data_1[] = { TOKEN_NUM, 0x01, 0x00 };
    const char line_data_2[] = { 'X' | NT_STOP };

    PRINT_TEST_NAME();

    initialize_program();

    call_parse_expression("1", line_data_1, sizeof line_data_1, __LINE__);
    call_parse_expression("X", line_data_2, sizeof line_data_2, __LINE__);

    // TODO: add more tests
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

    const char line_data_1[] = { TOKEN_NUM, 0x01, 0x00 };
    const char line_data_2[] = { 'X' | NT_STOP };
    const char line_data_3[] = { 'X' | NT_STOP, TOKEN_NO_VALUE };
    const char line_data_4[] = { 'X' | NT_STOP, 'Y' | NT_STOP, TOKEN_NO_VALUE };

    PRINT_TEST_NAME();

    initialize_program();

    call_parse_directive("1", 1, line_data_1, sizeof line_data_1, __LINE__);
    call_parse_directive("X", 1, line_data_2, sizeof line_data_2, __LINE__);
    call_parse_directive("X", NT_VAR, line_data_2, sizeof line_data_2, __LINE__);
    call_parse_directive("X", NT_RPT_VAR, line_data_3, sizeof line_data_3, __LINE__);
    call_parse_directive("X,Y", NT_RPT_VAR, line_data_4, sizeof line_data_4, __LINE__);
}

void call_parse_statement(const char* s, const char* expect_line_data, size_t expect_line_data_length, int line) {
    size_t expect_buffer_pos;
    fprintf(stderr, "  %s:%d: parse_statement(\"%s\")\n", __FILE__, line, s);
    expect_buffer_pos = strlen(s);
    strcpy(buffer, s);
    buffer_pos = 0;
    line_pos = offsetof(Line, data);
    parse_statement(statement_name_table);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(buffer_pos, expect_buffer_pos);
    ASSERT_MEMORY_EQ(line_buffer.data, expect_line_data, expect_line_data_length);
    ASSERT_EQ(line_pos, offsetof(Line, data) + expect_line_data_length);
}

void test_parse_statement(void) {

    const char line_data_1[] = { ST_RUN };
    const char line_data_2[] = { ST_PRINT, TOKEN_NUM, 0x08, 0x00 };
    const char line_data_3[] = { ST_LET, 'X' | NT_STOP, TOKEN_NUM, 0x64, 0x00 };
    const char line_data_4[] = { ST_INPUT, 'X' | NT_STOP, 'Y' | NT_STOP, TOKEN_NO_VALUE };
    const char line_data_5[] = { ST_LIST, TOKEN_NUM, 0x0A, 0x00, TOKEN_NUM, 0x14, 0x00  };

    PRINT_TEST_NAME();

    initialize_program();

    call_parse_statement("RUN", line_data_1, sizeof line_data_1, __LINE__);
    call_parse_statement("PRINT 8", line_data_2, sizeof line_data_2, __LINE__);
    call_parse_statement("LET X=100", line_data_3, sizeof line_data_3, __LINE__);
    call_parse_statement("INPUT X,Y", line_data_4, sizeof line_data_4, __LINE__);
    call_parse_statement("LIST 10,20", line_data_5, sizeof line_data_5, __LINE__);

    // Test that adding spaces here and there doesn't mix up the parser.

    call_parse_statement("PRINT    8", line_data_2, sizeof line_data_2, __LINE__);
    call_parse_statement("PRINT 8  ", line_data_2, sizeof line_data_2, __LINE__);
    call_parse_statement("LET   X  =  100  ", line_data_3, sizeof line_data_3, __LINE__);

    // Make sure the parser doesn't keep parsing past the end of the name table record.
    // Note the parser will skip the space after 8; that's okay.

    strcpy(buffer, "PRINT 8 9");
    buffer_pos = 0;
    line_pos = offsetof(Line, data);
    parse_statement(statement_name_table);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(buffer_pos, 8);
    ASSERT_EQ(line_pos, offsetof(Line, data) + sizeof line_data_2);

    // Make sure the parser doesn't match continued names.

    strcpy(buffer, "PRINTX");
    buffer_pos = 0;
    line_pos = offsetof(Line, data);
    parse_statement(statement_name_table);
    ASSERT_NE(err, 0);
    ASSERT_EQ(buffer_pos, 6);
}

void test_parse_line(void) {

    const char line_data_1[] = { ST_LET, 'X' | NT_STOP, TOKEN_NUM, 0x64, 0x00 };
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
    test_is_name_character();
    test_parse_name();
    test_char_to_digit();
    test_read_number();
    test_parse_expression();
    test_parse_argument_separator();
    test_parse_directive();
    test_parse_statement();
    test_parse_line();
    return 0;
}