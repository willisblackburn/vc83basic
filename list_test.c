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

    const char line_data_1[] = { TOKEN_NUM, 0x10, 0x10 };
    const char line_data_2[] = { 0x80 };
    const char line_data_3[] = { 0x80, TOKEN_NO_VALUE };
    const char line_data_4[] = { 0x80, 0x81, TOKEN_NO_VALUE };

    const char list_1[] = "4112";
    const char list_2[] = "X";
    const char list_3[] = "X";
    const char list_4[] = "X,Y";

    PRINT_TEST_NAME();

    initialize_program();
    create_varibles();

    list_directive(1, line_data_1, 0, 0);
    ASSERT_MEMORY_EQ(buffer, list_1, sizeof list_1 - 1);
    ASSERT_EQ(bp, sizeof list_1 - 1);

    list_directive(1, line_data_2, 0, 0);
    ASSERT_MEMORY_EQ(buffer, list_2, sizeof list_2 - 1);
    ASSERT_EQ(bp, sizeof list_2 - 1);

    list_directive(NT_VAR, line_data_2, 0, 0);
    ASSERT_MEMORY_EQ(buffer, list_2, sizeof list_2 - 1);
    ASSERT_EQ(bp, sizeof list_2 - 1);

    list_directive(NT_RPT_VAR, line_data_3, 0, 0);
    ASSERT_MEMORY_EQ(buffer, list_3, sizeof list_3 - 1);
    ASSERT_EQ(bp, sizeof list_3 - 1);

    list_directive(NT_RPT_VAR, line_data_4, 0, 0);
    ASSERT_MEMORY_EQ(buffer, list_4, sizeof list_4 - 1);
    ASSERT_EQ(bp, sizeof list_4 - 1);
}

static void test_list_element(void) {

    const char line_data_1[] = { 0x00 };
    const char line_data_2[] = { 0x80, TOKEN_NUM, 0xFF, 0x7F };
    const char line_data_3[] = { TOKEN_NUM, 0x0A, 0x00, TOKEN_NUM, 0x14, 0x00 };
    const char line_data_4[] = { TOKEN_NUM, 0x0A, 0x00, TOKEN_NO_VALUE };
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

    // list_element(statement_name_table, ST_LIST, line_data_3, 0, 0);
    // ASSERT_MEMORY_EQ(buffer, list_3, sizeof list_3 - 1);
    // ASSERT_EQ(bp, sizeof list_3 - 1);
    // ASSERT_EQ(lp, sizeof line_data_3);

    // list_element(statement_name_table, ST_LIST, line_data_4, 0, 0);
    // ASSERT_MEMORY_EQ(buffer, list_4, sizeof list_4 - 1);
    // ASSERT_EQ(bp, sizeof list_4 - 1);
    // ASSERT_EQ(lp, sizeof line_data_4);

    // list_element(statement_name_table, ST_LIST, line_data_5, 0, 0);
    // ASSERT_MEMORY_EQ(buffer, list_5, sizeof list_5 - 1);
    // ASSERT_EQ(bp, sizeof list_5 - 1);
    // ASSERT_EQ(lp, sizeof line_data_5);
}

static void test_list_line(void) {
    int err;

    const char line_data_1[] = { 7, 0x0A, 0x00, ST_PRINT, TOKEN_NUM, 0x01, 0x01 };
    const char line_data_2[] = { 3, 0x90, 0x01, ST_LET, 0x80, TOKEN_NUM, 0xFF, 0x7F };
    const char line_data_end[] = { 3, 0xFF, 0xFF };
    
    const char list_1[] = "10 PRINT 257";
    const char list_2[] = "400 LET X=32767";

    PRINT_TEST_NAME();

    initialize_program();
    create_varibles();

    err = list_line(line_data_1);
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(buffer, list_1, sizeof list_1 - 1);
    ASSERT_EQ(bp, sizeof list_1 - 1);

    err = list_line(line_data_2);
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(buffer, list_2, sizeof list_2 - 1);
    ASSERT_EQ(bp, sizeof list_2 - 1);

    // Test that list_line returns carry set when at the last line (or any negative-numbered line):

    err = list_line(line_data_end);
    ASSERT_NE(err, 0);
}

int main(void) {

    initialize_target();
    test_list_directive();
    test_list_element();
    test_list_line();

    return 0;
}
