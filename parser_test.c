#include "test.h"

static void test_char_to_digit(void) {
    int err;

    PRINT_TEST_NAME();

    err = char_to_digit('0');
    ASSERT_EQ(err, 0);
    ASSERT_EQ(reg_a, 0);
    err = char_to_digit('9');
    ASSERT_EQ(err, 0);
    ASSERT_EQ(reg_a, 9);
    err = char_to_digit('0'-1);
    ASSERT_NE(err, 0);
    err = char_to_digit('9'+1);
    ASSERT_NE(err, 0);
    err = char_to_digit(' ');
    ASSERT_NE(err, 0);
    err = char_to_digit('A');
    ASSERT_NE(err, 0);
    err = char_to_digit(0);
    ASSERT_NE(err, 0);
    err = char_to_digit(255);
    ASSERT_NE(err, 0);
}

static void test_read_number(void) {
    int err;

    PRINT_TEST_NAME();

    strcpy(buffer, "10 PRINT X");
    err = read_number(0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(reg_ax, 10);
    ASSERT_EQ(bp, 2);

    // The function should honor the current read position.
    strcpy(buffer, "1020 PRINT X");
    err = read_number(2);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(reg_ax, 20);
    ASSERT_EQ(bp, 4);

    // The function should return carry set if an invalid number.
    strcpy(buffer, "invalid");
    err = read_number(0);
    ASSERT_NE(err, 0);
    ASSERT_EQ(bp, 0);

    strcpy(buffer, "");
    err = read_number(0);
    ASSERT_NE(err, 0);
    ASSERT_EQ(bp, 0);
}

static void test_parse_expression(void) {
    int err;
    
    const char line_data_1[] = { TOKEN_NUM, 0x01, 0x00 };
    const char line_data_2[] = { 0x80 };

    PRINT_TEST_NAME();

    initialize_program();

    strcpy(buffer, "1");
    err = parse_expression(0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_1, sizeof line_data_1);
    ASSERT_EQ(bp, 1);
    ASSERT_EQ(lp, offsetof(Line, data) + sizeof line_data_1);

    strcpy(buffer, "X");
    err = parse_expression(0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_2, sizeof line_data_2);
    ASSERT_EQ(bp, 1);
    ASSERT_EQ(lp, offsetof(Line, data) + sizeof line_data_2);

    // TODO: add more tests
}

static void test_parse_directive(void) {
    int err;

    const char line_data_1[] = { TOKEN_NUM, 0x01, 0x00 };
    const char line_data_2[] = { 0x80 };

    PRINT_TEST_NAME();

    initialize_program();

    strcpy(buffer, "1");
    err = parse_directive(1, 0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_1, sizeof line_data_1);
    ASSERT_EQ(bp, 1);
    ASSERT_EQ(lp, offsetof(Line, data) + sizeof line_data_1);

    strcpy(buffer, "X");
    err = parse_directive(1, 0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_2, sizeof line_data_2);
    ASSERT_EQ(bp, 1);
    ASSERT_EQ(lp, offsetof(Line, data) + sizeof line_data_2);

    strcpy(buffer, "X");
    err = parse_directive(NT_VAR, 0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_2, sizeof line_data_2);
    ASSERT_EQ(bp, 1);
    ASSERT_EQ(lp, offsetof(Line, data) + sizeof line_data_2);
}

static void test_parse_element(void) {
    int err;
    const char line_data_1[] = { ST_RUN };
    const char line_data_2[] = { ST_PRINT, TOKEN_NUM, 0x08, 0x00 };
    const char line_data_3[] = { ST_LET, 0x80, TOKEN_NUM, 0x64, 0x00 };

    PRINT_TEST_NAME();

    initialize_program();

    strcpy(buffer, "RUN");
    err = parse_element(statement_name_table, 0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_1, sizeof line_data_1);
    ASSERT_EQ(bp, 3);
    ASSERT_EQ(lp, offsetof(Line, data) + sizeof line_data_1);

    strcpy(buffer, "PRINT 8");
    err = parse_element(statement_name_table, 0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_2, sizeof line_data_2);
    ASSERT_EQ(bp, 7);
    ASSERT_EQ(lp, offsetof(Line, data) + sizeof line_data_2);

    strcpy(buffer, "LET X=100");
    err = parse_element(statement_name_table, 0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_3, sizeof line_data_3);
    ASSERT_EQ(bp, 9);
    ASSERT_EQ(lp, offsetof(Line, data) + sizeof line_data_3);

    // Test that adding spaces here and there doesn't mix up the parser.

    strcpy(buffer, "PRINT    8");
    err = parse_element(statement_name_table, 0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    strcpy(buffer, "PRINT 8  ");
    err = parse_element(statement_name_table, 0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    strcpy(buffer, "LET   X  =  100  ");
    err = parse_element(statement_name_table, 0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
}

static void test_parse_line(void) {
    int err;

    const char line_data_1[] = { ST_LET, 0x80, TOKEN_NUM, 0x64, 0x00 };
    const char line_data_2[] = { ST_RUN };

    PRINT_TEST_NAME();

    initialize_program();

    // Happy path with line number.

    strcpy(buffer, "10 LET X=100");
    err = parse_line();
    ASSERT_EQ(err, 0);
    ASSERT_EQ(line_buffer.next_line_offset, offsetof(Line, data) + sizeof line_data_1);
    ASSERT_EQ(line_buffer.number, 10);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_1, sizeof line_data_1);

    // Happy path immediate mode.

    strcpy(buffer, "RUN");
    err = parse_line();
    ASSERT_EQ(err, 0);
    ASSERT_EQ(line_buffer.next_line_offset,  offsetof(Line, data) + sizeof line_data_2);
    ASSERT_EQ(line_buffer.number, -1);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_2, sizeof line_data_2);

    // Empty line

    strcpy(buffer, "");
    err = parse_line();
    ASSERT_EQ(err, 0);
    strcpy(buffer, "  ");
    err = parse_line();
    ASSERT_EQ(err, 0);

    // Test that the parser rejects statements that continue past the point where they're supposed to end.

    strcpy(buffer, "LET X=100,5");
    err = parse_line();
    ASSERT_NE(err, 0);
}

int main(void) {
    initialize_target();
    test_char_to_digit();
    test_read_number();
    test_parse_expression();
    test_parse_directive();
    test_parse_element();
    test_parse_line();
    return 0;
}
