#include "test.h"

static void create_varibles(void) {
    int err;

    // Create varibles which will get variable name table positions starting at 0.

    strcpy(buffer, "X");
    err = find_name(variable_name_table_ptr, 0);
    ASSERT_NE(err, 0);
    err = add_variable();
    ASSERT_EQ(err, 0);

    strcpy(buffer, "Y");
    err = find_name(variable_name_table_ptr, 0);
    ASSERT_NE(err, 0);
    err = add_variable();
    ASSERT_EQ(err, 0);
}

static void test_list_directive(void) {

    const char line_data_1[] = { TOKEN_NUM, 0x10, 0x10, TOKEN_NO_VALUE };
    const char line_data_2[] = { 0x80, TOKEN_NO_VALUE };
    const char line_data_3[] = { 0x80, TOKEN_NO_VALUE, TOKEN_NUM, 0x10, 0x10, TOKEN_NO_VALUE };
    const char line_data_4[] = { 0x80 };
    const char line_data_5[] = { 0x80, TOKEN_NO_VALUE };
    const char line_data_6[] = { 0x80, 0x81, TOKEN_NO_VALUE };
    const char line_data_7[] = { TOKEN_PAREN, 0x80, TOKEN_OP | OP_ADD, TOKEN_NUM, 0x03, 0x00, TOKEN_NO_VALUE,
        TOKEN_OP | OP_MUL, 0x81, TOKEN_NO_VALUE };
    const char line_data_8[] = { TOKEN_UNARY_OP | UNARY_OP_MINUS, 0x80, TOKEN_NO_VALUE };
    const char line_data_9[] = { TOKEN_NUM, 0x16, 0x00, TOKEN_OP | OP_DIV, TOKEN_NUM, 0x07, 0x00, TOKEN_NO_VALUE };
    const char line_data_10[] = { TOKEN_NUM, 0x16, 0x00, TOKEN_OP | OP_DIV, TOKEN_NUM, 0x07, 0x00, TOKEN_NO_VALUE,
        TOKEN_UNARY_OP | UNARY_OP_MINUS, 0x80, TOKEN_NO_VALUE };
    const char line_data_11[] = { 0x80, TOKEN_OP | OP_LE, TOKEN_NUM, 0x07, 0x00, TOKEN_OP | OP_OR,
        0x81, TOKEN_OP | OP_EQ, TOKEN_NUM, 0x10, 0x10, TOKEN_NO_VALUE };
    const char line_data_12[] = { TOKEN_PAREN, 0x80, TOKEN_OP | OP_ADD, TOKEN_NUM, 0x03, 0x00, TOKEN_NO_VALUE,
        TOKEN_OP | OP_AND, 0x81, TOKEN_NO_VALUE };
    const char line_data_13[] = { TOKEN_UNARY_OP | UNARY_OP_NOT, TOKEN_PAREN, 0x80, TOKEN_OP | OP_EQ,
        TOKEN_NUM, 0x03, 0x00, TOKEN_OP | OP_OR, TOKEN_UNARY_OP | UNARY_OP_NOT, TOKEN_UNARY_OP | UNARY_OP_MINUS, 
        0x81, TOKEN_NO_VALUE, TOKEN_NO_VALUE };

    const char list_1[] = "4112";
    const char list_2[] = "X";
    const char list_3[] = "X,4112";
    const char list_4[] = "X";
    const char list_5[] = "X";
    const char list_6[] = "X,Y";
    const char list_7[] = "(X+3)*Y";
    const char list_8[] = "-X";
    const char list_9[] = "22/7";
    const char list_10[] = "22/7,-X";
    const char list_11[] = "X<=7 OR Y=4112";
    const char list_12[] = "(X+3) AND Y";
    const char list_13[] = "NOT (X=3 OR NOT -Y)";

    PRINT_TEST_NAME();

    initialize_program();
    create_varibles();

    list_directive(1, line_data_1, 0, 0);
    ASSERT_MEMORY_EQ(buffer, list_1, sizeof list_1 - 1);
    ASSERT_EQ(bp, sizeof list_1 - 1);

    list_directive(1, line_data_2, 0, 0);
    ASSERT_MEMORY_EQ(buffer, list_2, sizeof list_2 - 1);
    ASSERT_EQ(bp, sizeof list_2 - 1);

    list_directive(2, line_data_3, 0, 0);
    ASSERT_MEMORY_EQ(buffer, list_3, sizeof list_3 - 1);
    ASSERT_EQ(bp, sizeof list_3 - 1);

    list_directive(NT_VAR, line_data_4, 0, 0);
    ASSERT_MEMORY_EQ(buffer, list_4, sizeof list_4 - 1);
    ASSERT_EQ(bp, sizeof list_4 - 1);

    list_directive(NT_RPT_VAR, line_data_5, 0, 0);
    ASSERT_MEMORY_EQ(buffer, list_5, sizeof list_5 - 1);
    ASSERT_EQ(bp, sizeof list_5 - 1);

    list_directive(NT_RPT_VAR, line_data_6, 0, 0);
    ASSERT_MEMORY_EQ(buffer, list_6, sizeof list_6 - 1);
    ASSERT_EQ(bp, sizeof list_6 - 1);

    list_directive(1, line_data_7, 0, 0);
    ASSERT_MEMORY_EQ(buffer, list_7, sizeof list_7 - 1);
    ASSERT_EQ(bp, sizeof list_7 - 1);

    list_directive(1, line_data_8, 0, 0);
    ASSERT_MEMORY_EQ(buffer, list_8, sizeof list_8 - 1);
    ASSERT_EQ(bp, sizeof list_8 - 1);

    list_directive(1, line_data_9, 0, 0);
    ASSERT_MEMORY_EQ(buffer, list_9, sizeof list_9 - 1);
    ASSERT_EQ(bp, sizeof list_9 - 1);

    list_directive(2, line_data_10, 0, 0);
    ASSERT_MEMORY_EQ(buffer, list_10, sizeof list_10 - 1);
    ASSERT_EQ(bp, sizeof list_10 - 1);

    list_directive(1, line_data_11, 0, 0);
    ASSERT_MEMORY_EQ(buffer, list_11, sizeof list_11 - 1);
    ASSERT_EQ(bp, sizeof list_11 - 1);

    list_directive(1, line_data_12, 0, 0);
    ASSERT_MEMORY_EQ(buffer, list_12, sizeof list_12 - 1);
    ASSERT_EQ(bp, sizeof list_12 - 1);

    list_directive(1, line_data_13, 0, 0);
    ASSERT_MEMORY_EQ(buffer, list_13, sizeof list_13 - 1);
    ASSERT_EQ(bp, sizeof list_13 - 1);
}

static void test_list_element(void) {

    const char line_data_1[] = { 0x00 };
    const char line_data_2[] = { 0x80, TOKEN_NUM, 0xFF, 0x7F, TOKEN_NO_VALUE };
    const char line_data_3[] = { TOKEN_NUM, 0x0A, 0x00, TOKEN_NO_VALUE, TOKEN_NUM, 0x14, 0x00, TOKEN_NO_VALUE };
    const char line_data_4[] = { TOKEN_NUM, 0x0A, 0x00, TOKEN_NO_VALUE, TOKEN_NO_VALUE };
    const char line_data_5[] = { TOKEN_NO_VALUE, TOKEN_NO_VALUE };
    
    const char list_1[] = "RUN";
    const char list_2[] = "LET X=32767";
    const char list_3[] = "LIST 10,20";
    const char list_4[] = "LIST 10";
    const char list_5[] = "LIST";

    PRINT_TEST_NAME();

    initialize_program();
    create_varibles();

    list_element(statement_name_table, ST_RUN, line_data_1, 0, 0);
    ASSERT_MEMORY_EQ(buffer, list_1, sizeof list_1 - 1);
    ASSERT_EQ(bp, sizeof list_1 - 1);
    ASSERT_EQ(lp, 0);

    list_element(statement_name_table, ST_LET, line_data_2, 0, 0);
    ASSERT_MEMORY_EQ(buffer, list_2, sizeof list_2 - 1);
    ASSERT_EQ(bp, sizeof list_2 - 1);
    ASSERT_EQ(lp, sizeof line_data_2);

    list_element(statement_name_table, ST_LIST, line_data_3, 0, 0);
    ASSERT_MEMORY_EQ(buffer, list_3, sizeof list_3 - 1);
    ASSERT_EQ(bp, sizeof list_3 - 1);
    ASSERT_EQ(lp, sizeof line_data_3);

    list_element(statement_name_table, ST_LIST, line_data_4, 0, 0);
    ASSERT_MEMORY_EQ(buffer, list_4, sizeof list_4 - 1);
    ASSERT_EQ(bp, sizeof list_4 - 1);
    ASSERT_EQ(lp, sizeof line_data_4);

    list_element(statement_name_table, ST_LIST, line_data_5, 0, 0);
    ASSERT_MEMORY_EQ(buffer, list_5, sizeof list_5 - 1);
    ASSERT_EQ(bp, sizeof list_5 - 1);
    ASSERT_EQ(lp, sizeof line_data_5);
}

static void test_list_line(void) {
    char err;

    const char line_data_1[] = { ST_PRINT, TOKEN_NUM, 0x01, 0x01, TOKEN_NO_VALUE };
    const char line_data_2[] = { ST_LET, 0x80, TOKEN_NUM, 0xFF, 0x7F, TOKEN_NO_VALUE };
    const char line_data_end[] = { 3, 0xFF, 0xFF };
    
    const char list_1[] = "10 PRINT 257";
    const char list_2[] = "400 LET X=32767";

    PRINT_TEST_NAME();

    initialize_program();
    create_varibles();

    set_line(10, line_data_1, sizeof line_data_1);
    err = list_line();
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(buffer, list_1, sizeof list_1 - 1);
    ASSERT_EQ(bp, sizeof list_1 - 1);

    set_line(400, line_data_2, sizeof line_data_2);
    err = list_line();
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(buffer, list_2, sizeof list_2 - 1);
    ASSERT_EQ(bp, sizeof list_2 - 1);

    // Test that list_line returns carry set when at the last line (or any negative-numbered line):

    set_line(-1, line_data_end, sizeof line_data_end);
    err = list_line();
    ASSERT_NE(err, 0);
}

int main(void) {

    initialize_target();
    test_list_directive();
    test_list_element();
    test_list_line();

    return 0;
}
