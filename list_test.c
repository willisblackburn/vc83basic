#include "test.h"

static void create_varibles(void) {
    int err;

    // Create varibles which will get variable name table positions starting at 0.

    strcpy(buffer, "X");
    err = find_name(variable_name_table_ptr, 0);
    ASSERT_NE(err, 0);
    err = add_variable();
    strcpy(buffer, "Y");
    err = find_name(variable_name_table_ptr, 0);
    ASSERT_NE(err, 0);
    err = add_variable();
    ASSERT_EQ(err, 0);
}

static void test_list_expression(void) {

    const char line_data_1[] = { TOKEN_INT, 0x10, 0x10 };
    const char line_data_2[] = { 0x80 };
    const char line_data_3[] = { TOKEN_NO_VALUE };
    const char line_data_4[] = { TOKEN_INT, 0x16, 0x00, TOKEN_BINARY_OP | OP_DIV, TOKEN_INT, 0x07, 0x00 };
    const char line_data_5[] = { 0x80, TOKEN_BINARY_OP | OP_LE, TOKEN_INT, 0x07, 0x00, TOKEN_BINARY_OP | OP_OR,
        0x81, TOKEN_BINARY_OP | OP_EQ, TOKEN_INT, 0x10, 0x10 };
    const char line_data_6[] = { TOKEN_OP | OP_LPAREN, 0x80, TOKEN_BINARY_OP | OP_ADD, TOKEN_INT, 0x03, 0x00,
        TOKEN_OP | OP_RPAREN, TOKEN_BINARY_OP | OP_MUL, 0x81 };

    const char list_1[] = "4112";
    const char list_2[] = "X";
    const char list_3[] = "";
    const char list_4[] = "22/7";
    const char list_5[] = "X<=7 OR Y=4112";
    const char list_6[] = "(X+3)*Y";

    PRINT_TEST_NAME();

    initialize_program();
    create_varibles();

    list_expression(line_data_1, sizeof line_data_1, 0, 0);
    ASSERT_MEMORY_EQ(buffer, list_1, sizeof list_1 - 1);
    ASSERT_EQ(bp, sizeof list_1 - 1);

    list_expression(line_data_2, sizeof line_data_2, 0, 0);
    ASSERT_MEMORY_EQ(buffer, list_2, sizeof list_2 - 1);
    ASSERT_EQ(bp, sizeof list_2 - 1);

    list_expression(line_data_3, sizeof line_data_3, 0, 0);
    ASSERT_MEMORY_EQ(buffer, list_3, sizeof list_3 - 1);
    ASSERT_EQ(bp, sizeof list_3 - 1);

    list_expression(line_data_4, sizeof line_data_4, 0, 0);
    ASSERT_MEMORY_EQ(buffer, list_4, sizeof list_4 - 1);
    ASSERT_EQ(bp, sizeof list_4 - 1);

    // Verify that LIST ignores a byte that looks like an operator after the end of the line.
    // The important thing is that bp (the buffer length) is 2 (i.e., the operator was not rendered).
    list_expression(line_data_4, 3, 0, 0);
    ASSERT_MEMORY_EQ(buffer, list_4, 2);
    ASSERT_EQ(bp, 2);

    list_expression(line_data_5, sizeof line_data_5, 0, 0);
    ASSERT_MEMORY_EQ(buffer, list_5, sizeof list_5 - 1);
    ASSERT_EQ(bp, sizeof list_5 - 1);

    list_expression(line_data_6, sizeof line_data_6, 0, 0);
    ASSERT_MEMORY_EQ(buffer, list_6, sizeof list_6 - 1);
    ASSERT_EQ(bp, sizeof list_6 - 1);
}

static void test_list_argument(void) {

    // list_argument just delegates to list_expression, so just do a quick sanity check.

    const char line_data_1[] = { TOKEN_INT, 0x10, 0x10 };

    const char list_1[] = { "4112" };

    PRINT_TEST_NAME();

    initialize_program();

    list_argument(line_data_1, sizeof line_data_1, 0, 0);
    ASSERT_MEMORY_EQ(buffer, list_1, sizeof list_1 - 1);
    ASSERT_EQ(bp, sizeof list_1 - 1);
}

static void test_list_repeated_argument(void) {
    
    const char line_data_1[] = { TOKEN_INT, 0x10, 0x10, 0x80, TOKEN_NO_VALUE };

    const char list_1[] = { "4112,X" };

    PRINT_TEST_NAME();

    initialize_program();
    create_varibles();

    list_repeated_argument(line_data_1, sizeof line_data_1, 0, 0);
    ASSERT_MEMORY_EQ(buffer, list_1, sizeof list_1 - 1);
    ASSERT_EQ(bp, sizeof list_1 - 1);
}

static void test_list_multiple_arguments(void) {
    
    const char line_data_1[] = { TOKEN_INT, 0x10, 0x10, 0x80, TOKEN_INT, 0x10, 0x00 };
    const char line_data_2[] = { TOKEN_INT, 0x10, 0x10, TOKEN_NO_VALUE, TOKEN_NO_VALUE };
    const char line_data_3[] = { TOKEN_NO_VALUE, TOKEN_NO_VALUE, TOKEN_NO_VALUE };

    const char list_1_1[] = { "4112" };
    const char list_1_2[] = { "4112,X" };
    const char list_1_3[] = { "4112,X,16" };
    const char list_2[] = { "4112" };
    const char list_3[] = { "" };

    PRINT_TEST_NAME();

    initialize_program();
    create_varibles();

    list_multiple_arguments(1, line_data_1, sizeof line_data_1, 0, 0);
    ASSERT_MEMORY_EQ(buffer, list_1_1, sizeof list_1_1 - 1);
    ASSERT_EQ(bp, sizeof list_1_1 - 1);
    list_multiple_arguments(2, line_data_1, sizeof line_data_1, 0, 0);
    ASSERT_MEMORY_EQ(buffer, list_1_2, sizeof list_1_2 - 1);
    ASSERT_EQ(bp, sizeof list_1_2 - 1);
    list_multiple_arguments(3, line_data_1, sizeof line_data_1, 0, 0);
    ASSERT_MEMORY_EQ(buffer, list_1_3, sizeof list_1_3 - 1);
    ASSERT_EQ(bp, sizeof list_1_3 - 1);

    list_multiple_arguments(3, line_data_2, sizeof line_data_2, 0, 0);
    ASSERT_MEMORY_EQ(buffer, list_2, sizeof list_2 - 1);
    ASSERT_EQ(bp, sizeof list_2 - 1);

    list_multiple_arguments(3, line_data_3, sizeof line_data_3, 0, 0);
    ASSERT_MEMORY_EQ(buffer, list_3, sizeof list_3 - 1);
    ASSERT_EQ(bp, sizeof list_3 - 1);
}

static void test_list_element(void) {

    const char line_data_1[] = { 0x00 };
    const char line_data_2[] = { 0x80, TOKEN_INT, 0xFF, 0x7F };
    const char line_data_3[] = { TOKEN_INT, 0x0A, 0x00, TOKEN_INT, 0x14, 0x00 };
    const char line_data_4[] = { TOKEN_INT, 0x0A, 0x00, TOKEN_NO_VALUE };
    const char line_data_5[] = { TOKEN_NO_VALUE, TOKEN_NO_VALUE };
    
    const char list_1[] = "RUN";
    const char list_2[] = "LET X=32767";
    const char list_3[] = "LIST 10,20";
    const char list_4[] = "LIST 10";
    const char list_5[] = "LIST";

    PRINT_TEST_NAME();

    initialize_program();
    create_varibles();

    list_element(statement_name_table, ST_RUN, line_data_1, sizeof line_data_1, 0, 0);
    ASSERT_MEMORY_EQ(buffer, list_1, sizeof list_1 - 1);
    ASSERT_EQ(bp, sizeof list_1 - 1);
    ASSERT_EQ(lp, 0);

    list_element(statement_name_table, ST_LET, line_data_2, sizeof line_data_2, 0, 0);
    ASSERT_MEMORY_EQ(buffer, list_2, sizeof list_2 - 1);
    ASSERT_EQ(bp, sizeof list_2 - 1);
    ASSERT_EQ(lp, sizeof line_data_2);

    list_element(statement_name_table, ST_LIST, line_data_3, sizeof line_data_3, 0, 0);
    ASSERT_MEMORY_EQ(buffer, list_3, sizeof list_3 - 1);
    ASSERT_EQ(bp, sizeof list_3 - 1);
    ASSERT_EQ(lp, sizeof line_data_3);

    list_element(statement_name_table, ST_LIST, line_data_4, sizeof line_data_4, 0, 0);
    ASSERT_MEMORY_EQ(buffer, list_4, sizeof list_4 - 1);
    ASSERT_EQ(bp, sizeof list_4 - 1);
    ASSERT_EQ(lp, sizeof line_data_4);

    list_element(statement_name_table, ST_LIST, line_data_5, sizeof line_data_5, 0, 0);
    ASSERT_MEMORY_EQ(buffer, list_5, sizeof list_5 - 1);
    ASSERT_EQ(bp, sizeof list_5 - 1);
    ASSERT_EQ(lp, sizeof line_data_5);
}

static void test_list_line(void) {
    int err;

    const char line_data_1[] = { 7, 0x0A, 0x00, ST_PRINT, TOKEN_INT, 0x01, 0x01 };
    const char line_data_2[] = { 3, 0x90, 0x01, ST_LET, 0x80, TOKEN_INT, 0xFF, 0x7F };
    const char line_data_end[] = { 3, 0xFF, 0xFF };
    
    const char list_1[] = "10 PRINT 257";
    const char list_2[] = "400 LET X=32767";

    PRINT_TEST_NAME();

    initialize_program();
    create_varibles();

    err = list_line(line_data_1, sizeof line_data_1);
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(buffer, list_1, sizeof list_1 - 1);
    ASSERT_EQ(bp, sizeof list_1 - 1);

    err = list_line(line_data_2, sizeof line_data_2);
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(buffer, list_2, sizeof list_2 - 1);
    ASSERT_EQ(bp, sizeof list_2 - 1);

    // Test that list_line returns carry set when at the last line (or any negative-numbered line):

    err = list_line(line_data_end, sizeof line_data_end);
    ASSERT_NE(err, 0);
}

int main(void) {

    initialize_target();
    test_list_expression();
    test_list_argument();
    test_list_repeated_argument();
    test_list_multiple_arguments();
    test_list_element();
    test_list_line();

    return 0;
}
