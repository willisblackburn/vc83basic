#include "test.h"

void add_variable_with_name(const char* name) {
    strcpy(buffer, name);
    name_start_pos = 0;
    buffer_pos = strlen(buffer);
    find_name(variable_name_table_ptr);
    ASSERT_NE(err, 0);
    add_variable();
    ASSERT_EQ(err, 0);
}

void create_variables(void) {

    // Create varibles which will get variable name table positions starting at 0.

    add_variable_with_name("X");
    add_variable_with_name("Y");
}

void call_list_directive(char directive, const char* line_data, size_t line_data_length,
    const char* expect_buffer, int line) {
    fprintf(stderr, "  %s:%d: list_directive(%d)\n", __FILE__, line, directive);
    set_line(0, line_data, line_data_length);
    buffer_pos = 0;
    list_directive(directive);
    ASSERT_MEMORY_EQ(buffer, expect_buffer, strlen(expect_buffer));
    ASSERT_EQ(buffer_pos, strlen(expect_buffer));
}

void test_list_directive(void) {

    const char line_data_1[] = { TOKEN_NUM, 0x10, 0x10 };
    const char line_data_2[] = { 0x80 };
    const char line_data_3[] = { 0x80, TOKEN_NUM, 0x10, 0x10 };
    const char line_data_4[] = { 0x80 };
    const char line_data_5[] = { 0x80, TOKEN_NO_VALUE };
    const char line_data_6[] = { 0x80, 0x81, TOKEN_NO_VALUE };

    const char list_1[] = "4112";
    const char list_2[] = "X";
    const char list_3[] = "X,4112";
    const char list_4[] = "X";
    const char list_5[] = "X";
    const char list_6[] = "X,Y";

    PRINT_TEST_NAME();

    initialize_program();
    create_variables();

    call_list_directive(1, line_data_1, sizeof line_data_1, list_1, __LINE__);
    call_list_directive(1, line_data_2, sizeof line_data_2, list_2, __LINE__);
    call_list_directive(2, line_data_3, sizeof line_data_3, list_3, __LINE__);
    call_list_directive(NT_VAR, line_data_4, sizeof line_data_4, list_4, __LINE__);
    call_list_directive(NT_RPT_VAR, line_data_5, sizeof line_data_5, list_5, __LINE__);
    call_list_directive(NT_RPT_VAR, line_data_6, sizeof line_data_6, list_6, __LINE__);
}

void call_list_statement(const char* line_data, size_t line_data_length, const char* expect_buffer, int line) {
    fprintf(stderr, "  %s:%d: list_statement()\n", __FILE__, line);
    set_line(0, line_data, line_data_length);
    buffer_pos = 0;
    list_statement();
    ASSERT_MEMORY_EQ(buffer, expect_buffer, strlen(expect_buffer));
    ASSERT_EQ(buffer_pos, strlen(expect_buffer));
}

void test_list_statment(void) {

    const char line_data_1[] = { ST_RUN };
    const char line_data_2[] = { ST_LET, 0x80, TOKEN_NUM, 0xFF, 0x7F };
    const char line_data_3[] = { ST_LIST, TOKEN_NUM, 0x0A, 0x00, TOKEN_NUM, 0x14, 0x00 };
    const char line_data_4[] = { ST_LIST, TOKEN_NUM, 0x0A, 0x00, TOKEN_NO_VALUE };
    const char line_data_5[] = { ST_LIST, TOKEN_NO_VALUE, TOKEN_NO_VALUE };
    const char line_data_6[] = { ST_INPUT, 0x80, 0x81, TOKEN_NO_VALUE };
    
    const char list_1[] = "RUN";
    const char list_2[] = "LET X=32767";
    const char list_3[] = "LIST 10,20";
    const char list_4[] = "LIST 10";
    const char list_5[] = "LIST";
    const char list_6[] = "INPUT X,Y";

    PRINT_TEST_NAME();

    initialize_program();
    create_variables();

    call_list_statement(line_data_1, sizeof line_data_1, list_1, __LINE__);
    call_list_statement(line_data_2, sizeof line_data_2, list_2, __LINE__);
    call_list_statement(line_data_3, sizeof line_data_3, list_3, __LINE__);
    call_list_statement(line_data_4, sizeof line_data_4, list_4, __LINE__);
    call_list_statement(line_data_5, sizeof line_data_5, list_5, __LINE__);
    call_list_statement(line_data_6, sizeof line_data_6, list_6, __LINE__);
}

void test_list_line(void) {

    const char line_data_1[] = { ST_PRINT, TOKEN_NUM, 0x01, 0x01 };
    const char line_data_2[] = { ST_LET, 0x80, TOKEN_NUM, 0xFF, 0x7F };
    const char line_data_end[] = { 3, 0xFF, 0xFF };
    
    const char list_1[] = "10 PRINT 257";
    const char list_2[] = "400 LET X=32767";

    PRINT_TEST_NAME();

    initialize_program();
    create_variables();

    set_line(10, line_data_1, sizeof line_data_1);
    list_line();
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(buffer, list_1, sizeof list_1 - 1);
    ASSERT_EQ(buffer_pos, sizeof list_1 - 1);

    set_line(400, line_data_2, sizeof line_data_2);
    list_line();
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(buffer, list_2, sizeof list_2 - 1);
    ASSERT_EQ(buffer_pos, sizeof list_2 - 1);

    // Test that list_line returns carry set when at the last line (or any negative-numbered line):

    set_line(-1, line_data_end, sizeof line_data_end);
    list_line();
    ASSERT_NE(err, 0);
}

int main(void) {

    initialize_target();
    test_list_directive();
    test_list_statment();
    test_list_line();

    return 0;
}
