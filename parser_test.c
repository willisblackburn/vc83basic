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
    
    const char line_data_1[] = { TOKEN_INT, 0x01, 0x00 };
    const char line_data_2[] = { 0x80 };

    PRINT_TEST_NAME();

    initialize_program();

    strcpy(buffer, "1");
    err = parse_expression(0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_1, sizeof line_data_1);
    ASSERT_EQ(bp, 1);
    ASSERT_EQ(lp, offsetof(Line, data) + 3);

    strcpy(buffer, "X");
    err = parse_expression(0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_2, sizeof line_data_2);
    ASSERT_EQ(bp, 1);
    ASSERT_EQ(lp, offsetof(Line, data) + 1);

    // TODO: add more tests
}

static void test_parse_argument_separator(void) {
    int err;

    PRINT_TEST_NAME();

    strcpy(buffer, ",");
    err = parse_argument_separator(0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(bp, 1);

    strcpy(buffer, "  ,");
    err = parse_argument_separator(0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(bp, 3);

    strcpy(buffer, "x");
    err = parse_argument_separator(0);
    ASSERT_NE(err, 0);
    ASSERT_EQ(bp, 0);

    strcpy(buffer, ",");
    err = parse_argument_separator(1);
    ASSERT_NE(err, 0);
    ASSERT_EQ(bp, 1);
}

static void test_parse_argument(void) {
    int err;

    const char line_data_1[] = { TOKEN_INT, 0x01, 0x00 };
    const char line_data_2[] = { 0x80 };

    PRINT_TEST_NAME();

    initialize_program();

    strcpy(buffer, "1");
    err = parse_argument(NT_EXPRESSION, 0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_1, sizeof line_data_1);
    ASSERT_EQ(bp, 1);
    ASSERT_EQ(lp, offsetof(Line, data) + sizeof line_data_1);

    strcpy(buffer, "1");
    err = parse_argument(NT_NUMBER, 0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_1, sizeof line_data_1);
    ASSERT_EQ(bp, 1);
    ASSERT_EQ(lp, offsetof(Line, data) + sizeof line_data_1);

    strcpy(buffer, "X");
    err = parse_argument(NT_VAR, 0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_2, sizeof line_data_2);
    ASSERT_EQ(bp, 1);
    ASSERT_EQ(lp, offsetof(Line, data) + sizeof line_data_2);
}

static void test_parse_repeated_argument(void) {
    int err;

    const char line_data_1[] = { TOKEN_INT, 0x01, 0x00, TOKEN_NO_VALUE };
    const char line_data_2[] = { TOKEN_INT, 0x01, 0x00, TOKEN_INT, 0x01, 0x00, TOKEN_NO_VALUE };
    const char line_data_3[] = { 0x80, TOKEN_NO_VALUE };
    const char line_data_4[] = { 0x80, 0x81, TOKEN_NO_VALUE };
    const char line_data_5[] = { TOKEN_NO_VALUE };

    PRINT_TEST_NAME();

    initialize_program();

    strcpy(buffer, "1");
    err = parse_repeated_argument(NT_RPT_EXPRESSION, 0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_1, sizeof line_data_1);
    ASSERT_EQ(bp, 1);
    ASSERT_EQ(lp, offsetof(Line, data) + sizeof line_data_1);

    strcpy(buffer, "1,1");
    err = parse_repeated_argument(NT_RPT_EXPRESSION, 0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_2, sizeof line_data_2);
    ASSERT_EQ(bp, 3);
    ASSERT_EQ(lp, offsetof(Line, data) + sizeof line_data_2);

    strcpy(buffer, "1");
    err = parse_repeated_argument(NT_RPT_NUMBER, 0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_1, sizeof line_data_1);
    ASSERT_EQ(bp, 1);
    ASSERT_EQ(lp, offsetof(Line, data) + sizeof line_data_1);

    strcpy(buffer, "1,1");
    err = parse_repeated_argument(NT_RPT_NUMBER, 0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_2, sizeof line_data_2);
    ASSERT_EQ(bp, 3);
    ASSERT_EQ(lp, offsetof(Line, data) + sizeof line_data_2);

    strcpy(buffer, "X");
    err = parse_repeated_argument(NT_RPT_VAR, 0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_3, sizeof line_data_3);
    ASSERT_EQ(bp, 1);
    ASSERT_EQ(lp, offsetof(Line, data) + sizeof line_data_3);

    strcpy(buffer, "X,Y");
    err = parse_repeated_argument(NT_RPT_VAR, 0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_4, sizeof line_data_4);
    ASSERT_EQ(bp, 3);
    ASSERT_EQ(lp, offsetof(Line, data) + sizeof line_data_4);

    strcpy(buffer, "");
    err = parse_repeated_argument(NT_RPT_EXPRESSION, 0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_5, sizeof line_data_5);
    ASSERT_EQ(bp, 0);
    ASSERT_EQ(lp, offsetof(Line, data) + sizeof line_data_5);

    strcpy(buffer, ",");
    err = parse_repeated_argument(NT_RPT_EXPRESSION, 0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_5, sizeof line_data_5);
    ASSERT_EQ(bp, 0);
    ASSERT_EQ(lp, offsetof(Line, data) + sizeof line_data_5);
}

static void test_parse_multiple_arguments(void) {
    int err;

    const char line_data_1[] = { TOKEN_INT, 0x01, 0x00 };
    const char line_data_2[] = { TOKEN_INT, 0x01, 0x00 };
    const char line_data_3[] = { TOKEN_INT, 0x01, 0x00, TOKEN_INT, 0x00, 0x01 };
    const char line_data_4[] = { 0x80, 0x81, TOKEN_INT, 0x40, 0x00 };

    PRINT_TEST_NAME();

    initialize_program();

    strcpy(buffer, "1");
    err = parse_multiple_arguments(1, 0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_1, sizeof line_data_1);
    ASSERT_EQ(bp, 1);
    ASSERT_EQ(lp, offsetof(Line, data) + sizeof line_data_1);

    strcpy(buffer, "1,");
    err = parse_multiple_arguments(1, 0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_2, sizeof line_data_2);
    ASSERT_EQ(bp, 1);
    ASSERT_EQ(lp, offsetof(Line, data) + sizeof line_data_1);

    strcpy(buffer, "1,256");
    err = parse_multiple_arguments(2, 0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_3, sizeof line_data_3);
    ASSERT_EQ(bp, 5);
    ASSERT_EQ(lp, offsetof(Line, data) + sizeof line_data_3);

    strcpy(buffer, "X,Y,64");
    err = parse_multiple_arguments(3, 0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_4, sizeof line_data_4);
    ASSERT_EQ(bp, 6);
    ASSERT_EQ(lp, offsetof(Line, data) + sizeof line_data_4);

    strcpy(buffer, "1");
    err = parse_multiple_arguments(2, 0, offsetof(Line, data));
    ASSERT_NE(err, 0);

    strcpy(buffer, "1,");
    err = parse_multiple_arguments(2, 0, offsetof(Line, data));
    ASSERT_NE(err, 0);
}

static void test_parse_optional_multiple_arguments(void) {
    int err;

    const char line_data_1[] = { TOKEN_INT, 0x01, 0x00, TOKEN_NO_VALUE };
    const char line_data_2[] = { TOKEN_NO_VALUE, TOKEN_NO_VALUE };
    const char line_data_3[] = { TOKEN_INT, 0x01, 0x00 };

    PRINT_TEST_NAME();

    initialize_program();

    strcpy(buffer, "1");
    err = parse_multiple_arguments(2 | NT_OPTIONAL, 0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_1, sizeof line_data_1);
    ASSERT_EQ(bp, 1);
    ASSERT_EQ(lp, offsetof(Line, data) + sizeof line_data_1);

    strcpy(buffer, "1,");
    err = parse_multiple_arguments(2 | NT_OPTIONAL, 0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_1, sizeof line_data_1);
    ASSERT_EQ(bp, 1);
    ASSERT_EQ(lp, offsetof(Line, data) + sizeof line_data_1);

    strcpy(buffer, "1,");
    err = parse_multiple_arguments(2 | NT_OPTIONAL, 0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_1, sizeof line_data_1);
    ASSERT_EQ(bp, 1);
    ASSERT_EQ(lp, offsetof(Line, data) + sizeof line_data_1);

    strcpy(buffer, "");
    err = parse_multiple_arguments(2 | NT_OPTIONAL, 0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_2, sizeof line_data_2);
    ASSERT_EQ(bp, 0);
    ASSERT_EQ(lp, offsetof(Line, data) + sizeof line_data_2);

    strcpy(buffer, "1,2,3,4");
    err = parse_multiple_arguments(1 | NT_OPTIONAL, 0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_3, sizeof line_data_3);
    ASSERT_EQ(bp, 1);
    ASSERT_EQ(lp, offsetof(Line, data) + sizeof line_data_3);
}

static void test_parse_element(void) {
    int err;
    const char line_data_1[] = { 0x00 };
    const char line_data_2[] = { 0x01, TOKEN_INT, 0x08, 0x00 };
    const char line_data_3[] = { 0x02, 0x80, TOKEN_INT, 0x64, 0x00 };
    const char line_data_4[] = { 0x03, 0x80, 0x81, TOKEN_NO_VALUE };

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

    strcpy(buffer, "INPUT X,Y");
    err = parse_element(statement_name_table, 0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_4, sizeof line_data_4);
    ASSERT_EQ(bp, 9);
    ASSERT_EQ(lp, offsetof(Line, data) + sizeof line_data_4);

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

int main(void) {
    initialize_target();
    test_char_to_digit();
    test_read_number();
    test_parse_expression();
    test_parse_argument_separator();
    test_parse_argument();
    test_parse_repeated_argument();
    test_parse_multiple_arguments();
    test_parse_optional_multiple_arguments();
    test_parse_element();
    return 0;
}