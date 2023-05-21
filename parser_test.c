#include "test.h"

 static void test_is_name_character(void) {

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

 static void call_parse_name(const char* s, char set_bp) {
    strcpy(buffer, s);
    bp = set_bp;
    parse_name();
}

static void test_parse_name(void) {

    PRINT_TEST_NAME();

    call_parse_name("PRINT", 0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(name_bp, 0);
    ASSERT_EQ(bp, 5);

    // Start at the space to verify that it skips whitespace.
    call_parse_name("10 PRINT", 2);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(name_bp, 3);
    ASSERT_EQ(bp, 8);

    call_parse_name("10 PRINT X", 3);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(name_bp, 3);
    ASSERT_EQ(bp, 8);

    call_parse_name("10 PRINTX", 3);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(name_bp, 3);
    ASSERT_EQ(bp, 9);

    call_parse_name("10 PRINT10", 3);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(name_bp, 3);
    ASSERT_EQ(bp, 10);

    call_parse_name("10 PRINT10X", 3);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(name_bp, 3);
    ASSERT_EQ(bp, 11);

    // Start parse at space.
    call_parse_name("ON X/2 GOTO 10,20", 2);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(name_bp, 3);
    ASSERT_EQ(bp, 4);
    call_parse_name("ON X/2 GOTO 10,20", 6);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(name_bp, 7);
    ASSERT_EQ(bp, 11);

    // Digits are names; this is okay because we try to parse numbers before names.
    call_parse_name("10", 0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(name_bp, 0);
    ASSERT_EQ(bp, 2);

    // bp will reflect skipped whitespace even if parse fails.
    call_parse_name("   ", 0);
    ASSERT_NE(err, 0);
    ASSERT_EQ(bp, 3);

    call_parse_name("", 0);
    ASSERT_NE(err, 0);
    ASSERT_EQ(bp, 0);
}

static void test_char_to_digit(void) {
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

static void test_read_number(void) {
    int number;

    PRINT_TEST_NAME();

    strcpy(buffer, "10 PRINT X");
    number = read_number(0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(number, 10);
    ASSERT_EQ(bp, 2);

    // The function should honor the current read position.
    strcpy(buffer, "1020 PRINT X");
    number = read_number(2);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(number, 20);
    ASSERT_EQ(bp, 4);

    // The function should return carry set if an invalid number.
    strcpy(buffer, "invalid");
    read_number(0);
    ASSERT_NE(err, 0);
    ASSERT_EQ(bp, 0);

    strcpy(buffer, "");
    read_number(0);
    ASSERT_NE(err, 0);
    ASSERT_EQ(bp, 0);
}

static void test_parse_expression(void) {
    
    const char line_data_1[] = { TOKEN_NUM, 0x01, 0x00 };
    const char line_data_2[] = { 0x80 };

    PRINT_TEST_NAME();

    initialize_program();

    strcpy(buffer, "1");
    parse_expression(0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_1, sizeof line_data_1);
    ASSERT_EQ(bp, 1);
    ASSERT_EQ(lp, offsetof(Line, data) + sizeof line_data_1);

    strcpy(buffer, "X");
    parse_expression(0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_2, sizeof line_data_2);
    ASSERT_EQ(bp, 1);
    ASSERT_EQ(lp, offsetof(Line, data) + sizeof line_data_2);

    // TODO: add more tests
}

static void test_parse_argument_separator(void) {

    PRINT_TEST_NAME();

    strcpy(buffer, ",");
    parse_argument_separator(0);
    ASSERT_NE(err, 0);
    ASSERT_EQ(bp, 1);

    strcpy(buffer, "  ,");
    parse_argument_separator(0);
    ASSERT_NE(err, 0);
    ASSERT_EQ(bp, 3);

    strcpy(buffer, "x");
    parse_argument_separator(0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(bp, 0);

    strcpy(buffer, ",");
    parse_argument_separator(1);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(bp, 1);
}

static void test_parse_directive(void) {

    const char line_data_1[] = { TOKEN_NUM, 0x01, 0x00 };
    const char line_data_2[] = { 0x80 };
    const char line_data_3[] = { 0x80, TOKEN_NO_VALUE };
    const char line_data_4[] = { 0x80, 0x81, TOKEN_NO_VALUE };

    PRINT_TEST_NAME();

    initialize_program();

    strcpy(buffer, "1");
    parse_directive(1, 0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_1, sizeof line_data_1);
    ASSERT_EQ(bp, 1);
    ASSERT_EQ(lp, offsetof(Line, data) + sizeof line_data_1);

    strcpy(buffer, "X");
    parse_directive(1, 0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_2, sizeof line_data_2);
    ASSERT_EQ(bp, 1);
    ASSERT_EQ(lp, offsetof(Line, data) + sizeof line_data_2);

    strcpy(buffer, "X");
    parse_directive(NT_VAR, 0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_2, sizeof line_data_2);
    ASSERT_EQ(bp, 1);
    ASSERT_EQ(lp, offsetof(Line, data) + sizeof line_data_2);

    strcpy(buffer, "X");
    parse_directive(NT_RPT_VAR, 0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_3, sizeof line_data_3);
    ASSERT_EQ(bp, 1);
    ASSERT_EQ(lp, offsetof(Line, data) + sizeof line_data_3);

    strcpy(buffer, "X,Y");
    parse_directive(NT_RPT_VAR, 0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_4, sizeof line_data_4);
    ASSERT_EQ(bp, 3);
    ASSERT_EQ(lp, offsetof(Line, data) + sizeof line_data_4);
}

static void call_parse_statement(const char* s, const char* expect_line_data, size_t expect_line_data_length,
    int line) {
    fprintf(stderr, "  %s:%d: parse_statement(\"%s\")\n", __FILE__, line, s);
    strcpy(buffer, s);
    bp = 0;
    lp = offsetof(Line, data);
    parse_statement(statement_name_table);
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, expect_line_data, expect_line_data_length);
    ASSERT_EQ(lp, offsetof(Line, data) + expect_line_data_length);
}

static void test_parse_statement(void) {

    const char line_data_1[] = { ST_RUN };
    const char line_data_2[] = { ST_PRINT, TOKEN_NUM, 0x08, 0x00 };
    const char line_data_3[] = { ST_LET, 0x80, TOKEN_NUM, 0x64, 0x00 };
    const char line_data_4[] = { ST_INPUT, 0x80, 0x81, TOKEN_NO_VALUE };

    PRINT_TEST_NAME();

    initialize_program();

    call_parse_statement("RUN", line_data_1, sizeof line_data_1, __LINE__);
    call_parse_statement("PRINT 8", line_data_2, sizeof line_data_2, __LINE__);
    call_parse_statement("LET X=100", line_data_3, sizeof line_data_3, __LINE__);
    call_parse_statement("INPUT X,Y", line_data_4, sizeof line_data_4, __LINE__);

    // Test that adding spaces here and there doesn't mix up the parser.

    call_parse_statement("PRINT    8", line_data_2, sizeof line_data_2, __LINE__);
    call_parse_statement("PRINT 8  ", line_data_2, sizeof line_data_2, __LINE__);
    call_parse_statement("LET   X  =  100  ", line_data_3, sizeof line_data_3, __LINE__);

    // Make sure the parser doesn't match continued names.

    strcpy(buffer, "PRINTX");
    bp = 0;
    lp = offsetof(Line, data);
    parse_statement(statement_name_table);
    ASSERT_NE(err, 0);
    ASSERT_EQ(bp, 6);
    ASSERT_EQ(lp, 3);
}

static void test_parse_line(void) {

    const char line_data_1[] = { ST_LET, 0x80, TOKEN_NUM, 0x64, 0x00 };
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
