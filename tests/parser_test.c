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

 void call_parse_name(const char* s, char set_buffer_pos) {
    strcpy(buffer, s);
    buffer_pos = set_buffer_pos;
    parse_name();
}

void test_parse_name(void) {

    PRINT_TEST_NAME();

    call_parse_name("PRINT", 0);
    ASSERT_EQ(err, 0);
    ASSERT_PTR_EQ(name_ptr, buffer);
    ASSERT_EQ(name_length, 5);
    ASSERT_EQ(buffer_pos, 5);

    // Start at the space to verify that it skips whitespace.
    call_parse_name("10 PRINT", 2);
    ASSERT_EQ(err, 0);
    ASSERT_PTR_EQ(name_ptr, buffer + 3);
    ASSERT_EQ(name_length, 5);
    ASSERT_EQ(buffer_pos, 8);

    call_parse_name("10 PRINT X", 3);
    ASSERT_EQ(err, 0);
    ASSERT_PTR_EQ(name_ptr, buffer + 3);
    ASSERT_EQ(name_length, 5);
    ASSERT_EQ(buffer_pos, 8);

    call_parse_name("10 PRINTX", 3);
    ASSERT_EQ(err, 0);
    ASSERT_PTR_EQ(name_ptr, buffer + 3);
    ASSERT_EQ(name_length, 6);
    ASSERT_EQ(buffer_pos, 9);

    call_parse_name("10 PRINT10", 3);
    ASSERT_EQ(err, 0);
    ASSERT_PTR_EQ(name_ptr, buffer + 3);
    ASSERT_EQ(name_length, 7);
    ASSERT_EQ(buffer_pos, 10);

    call_parse_name("10 PRINT10X", 3);
    ASSERT_EQ(err, 0);
    ASSERT_PTR_EQ(name_ptr, buffer + 3);
    ASSERT_EQ(name_length, 8);
    ASSERT_EQ(buffer_pos, 11);

    // Start parse at space.
    call_parse_name("ON X/2 GOTO 10,20", 2);
    ASSERT_EQ(err, 0);
    ASSERT_PTR_EQ(name_ptr, buffer + 3);
    ASSERT_EQ(name_length, 1);
    ASSERT_EQ(buffer_pos, 4);
    call_parse_name("ON X/2 GOTO 10,20", 6);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(name_ptr, buffer + 7);
    ASSERT_EQ(name_length, 4);
    ASSERT_EQ(buffer_pos, 11);

    // Digits are names; this is okay because we try to parse numbers before names.
    call_parse_name("10", 0);
    ASSERT_EQ(err, 0);
    ASSERT_PTR_EQ(name_ptr, buffer);
    ASSERT_EQ(name_length, 2);
    ASSERT_EQ(buffer_pos, 2);

    // buffer_pos will reflect skipped whitespace even if parse fails.
    call_parse_name("   ", 0);
    ASSERT_NE(err, 0);
    ASSERT_EQ(buffer_pos, 3);

    call_parse_name("", 0);
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
    size_t s_length;
    fprintf(stderr, "  %s:%d: parse_expression(\"%s\")\n", __FILE__, line, s);
    s_length = strlen(s);
    strcpy(buffer, s);
    buffer_pos = 0;
    line_pos = offsetof(Line, data);
    parse_expression();
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, expect_line_data, expect_line_data_size);
    ASSERT_EQ(buffer_pos, s_length);
    ASSERT_EQ(line_pos, offsetof(Line, data) + expect_line_data_size);
}

void test_parse_expression(void) {
    
    const char line_data_1[] = { TOKEN_NUM, 0x01, 0x00 };
    const char line_data_2[] = { TOKEN_VAR | 1, 'X' };

    PRINT_TEST_NAME();

    initialize_program();

    call_parse_expression("1", line_data_1, sizeof line_data_1, __LINE__);
    call_parse_expression("X", line_data_2, sizeof line_data_2, __LINE__);

    // TODO: add more tests
}

void call_parse_directive(const char* s, char directive, const char* expect_line_data, size_t expect_line_data_length, 
        int line) {
    size_t s_length;
    fprintf(stderr, "  %s:%d: parse_directive(\"%s\", %d)\n", __FILE__, line, s, directive);
    s_length = strlen(s);
    strcpy(buffer, s);
    buffer_pos = 0;
    line_pos = offsetof(Line, data);
    parse_directive(directive);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(buffer_pos, s_length);
    ASSERT_MEMORY_EQ(line_buffer.data, expect_line_data, expect_line_data_length);
    ASSERT_EQ(line_pos, offsetof(Line, data) + expect_line_data_length);
}

void test_parse_directive(void) {

    const char line_data_1[] = { TOKEN_NUM, 0x01, 0x00 };
    const char line_data_2[] = { TOKEN_VAR | 1, 'X' };

    PRINT_TEST_NAME();

    initialize_program();

    call_parse_directive("1", 1, line_data_1, sizeof line_data_1, __LINE__);
    call_parse_directive("X", 1, line_data_2, sizeof line_data_2, __LINE__);
}

void call_parse_statement(const char* s, const char* expect_line_data, size_t expect_line_data_length, int line) {
    size_t s_length;
    fprintf(stderr, "  %s:%d: parse_statement(\"%s\")\n", __FILE__, line, s);
    s_length = strlen(s);
    strcpy(buffer, s);
    buffer_pos = 0;
    line_pos = offsetof(Line, data);
    parse_statement(statement_name_table);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(buffer_pos, s_length);
    ASSERT_MEMORY_EQ(line_buffer.data, expect_line_data, expect_line_data_length);
    ASSERT_EQ(line_pos, offsetof(Line, data) + expect_line_data_length);
}

void test_parse_statement(void) {

    const char line_data_1[] = { ST_RUN };
    const char line_data_2[] = { ST_PRINT, TOKEN_NUM, 0x08, 0x00 };
    const char line_data_3[] = { ST_LET, TOKEN_VAR | 1, 'X', TOKEN_NUM, 0x64, 0x00 };

    PRINT_TEST_NAME();

    initialize_program();

    call_parse_statement("RUN", line_data_1, sizeof line_data_1, __LINE__);
    call_parse_statement("PRINT 8", line_data_2, sizeof line_data_2, __LINE__);
    call_parse_statement("LET X=100", line_data_3, sizeof line_data_3, __LINE__);

    // Test that adding spaces here and there doesn't mix up the parser.

    call_parse_statement("PRINT    8", line_data_2, sizeof line_data_2, __LINE__);
    call_parse_statement("PRINT 8  ", line_data_2, sizeof line_data_2, __LINE__);
    call_parse_statement("LET   X  =  100  ", line_data_3, sizeof line_data_3, __LINE__);

    // Make sure the parser doesn't match continued names.

    strcpy(buffer, "PRINTX");
    buffer_pos = 0;
    line_pos = offsetof(Line, data);
    parse_statement(statement_name_table);
    ASSERT_NE(err, 0);
    ASSERT_EQ(buffer_pos, 6);
    ASSERT_EQ(line_pos, 3);
}

void test_parse_line(void) {

    const char line_data_1[] = { ST_LET, TOKEN_VAR | 1, 'X', TOKEN_NUM, 0x64, 0x00 };
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
    test_parse_directive();
    test_parse_statement();
    test_parse_line();
    return 0;
}
