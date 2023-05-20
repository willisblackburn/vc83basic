#include "test.h"

static void add_variable_with_name(const char* name) {
    strcpy(buffer, name);
    name_bp = 0;
    bp = strlen(buffer);
    find_name(variable_name_table_ptr);
    ASSERT_NE(err, 0);
    add_variable();
    ASSERT_EQ(err, 0);
}

static void create_variables(void) {

    // Create varibles which will get variable name table positions starting at 0.

    add_variable_with_name("X");
    add_variable_with_name("Y");
}

static void call_list_directive(char directive, const char* line_data, size_t line_data_length,
    const char* expect_buffer, int line) {
    fprintf(stderr, "  %s:%d: list_directive(%d)\n", __FILE__, line, directive);
    set_line(0, line_data, line_data_length);
    bp = 0;
    list_directive(directive);
    ASSERT_MEMORY_EQ(buffer, expect_buffer, strlen(expect_buffer));
    ASSERT_EQ(bp, strlen(expect_buffer));
}

static void test_list_directive(void) {
    const char line_data_1[] = { TOKEN_NUM, 0x00, 0x00, 0x80, 0x00, 139, TOKEN_NO_VALUE };
    const char line_data_2[] = { 0x80, TOKEN_NO_VALUE };
    const char line_data_3[] = { 0x80, TOKEN_NO_VALUE, TOKEN_NUM, 0x00, 0x00, 0x80, 0x00, 139, TOKEN_NO_VALUE };
    const char line_data_4[] = { 0x80 };
    const char line_data_5[] = { 0x80, TOKEN_NO_VALUE };
    const char line_data_6[] = { 0x80, 0x81, TOKEN_NO_VALUE };
    const char line_data_7[] = { TOKEN_PAREN, 0x80, TOKEN_OP | OP_ADD, TOKEN_NUM, 0x00, 0x00, 0x00, 0x40, 128,
        TOKEN_NO_VALUE, TOKEN_OP | OP_MUL, 0x81, TOKEN_NO_VALUE };
    const char line_data_8[] = { TOKEN_UNARY_OP | UNARY_OP_MINUS, 0x80, TOKEN_NO_VALUE };
    const char line_data_9[] = { TOKEN_NUM, 0x00, 0x00, 0x00, 0x30, 131, TOKEN_OP | OP_DIV,
        TOKEN_NUM, 0x00, 0x00, 0x00, 0x60, 129, TOKEN_NO_VALUE };
    const char line_data_10[] = { TOKEN_NUM, 0x00, 0x00, 0x00, 0x30, 131, TOKEN_OP | OP_DIV,
        TOKEN_NUM, 0x00, 0x00, 0x00, 0x60, 129, TOKEN_NO_VALUE,
        TOKEN_UNARY_OP | UNARY_OP_MINUS, 0x80, TOKEN_NO_VALUE };
    const char line_data_11[] = { 0x80, TOKEN_OP | OP_LE, TOKEN_NUM, 0x00, 0x00, 0x00, 0x60, 129, TOKEN_OP | OP_OR,
        0x81, TOKEN_OP | OP_EQ, TOKEN_NUM, 0x00, 0x00, 0x80, 0x00, 139, TOKEN_NO_VALUE };
    const char line_data_12[] = { TOKEN_PAREN, 0x80, TOKEN_OP | OP_ADD, TOKEN_NUM, 0x00, 0x00, 0x00, 0x40, 128,
        TOKEN_NO_VALUE, TOKEN_OP | OP_AND, 0x81, TOKEN_NO_VALUE };
    const char line_data_13[] = { TOKEN_UNARY_OP | UNARY_OP_NOT, TOKEN_PAREN, 0x80, TOKEN_OP | OP_EQ,
        TOKEN_NUM, 0x00, 0x00, 0x00, 0x40, 128, TOKEN_OP | OP_OR, TOKEN_UNARY_OP | UNARY_OP_NOT,
        TOKEN_UNARY_OP | UNARY_OP_MINUS,  0x81, TOKEN_NO_VALUE, TOKEN_NO_VALUE };

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
    create_variables();

    call_list_directive(1, line_data_1, sizeof line_data_1, list_1, __LINE__);
    call_list_directive(1, line_data_2, sizeof line_data_2, list_2, __LINE__);
    call_list_directive(2, line_data_3, sizeof line_data_3, list_3, __LINE__);
    call_list_directive(NT_VAR, line_data_4, sizeof line_data_4, list_4, __LINE__);
    call_list_directive(NT_RPT_VAR, line_data_5, sizeof line_data_5, list_5, __LINE__);
    call_list_directive(NT_RPT_VAR, line_data_6, sizeof line_data_6, list_6, __LINE__);
    call_list_directive(1, line_data_7, sizeof line_data_7, list_7, __LINE__);
    call_list_directive(1, line_data_8, sizeof line_data_8, list_8, __LINE__);
    call_list_directive(1, line_data_9, sizeof line_data_9, list_9, __LINE__);
    call_list_directive(2, line_data_10, sizeof line_data_10, list_10, __LINE__);
    call_list_directive(1, line_data_11, sizeof line_data_11, list_11, __LINE__);
    call_list_directive(1, line_data_12, sizeof line_data_12, list_12, __LINE__);
    call_list_directive(1, line_data_13, sizeof line_data_13, list_13, __LINE__);
}

static void call_list_statement(const char* line_data, size_t line_data_length, const char* expect_buffer, int line) {
    fprintf(stderr, "  %s:%d: list_statement()\n", __FILE__, line);
    set_line(0, line_data, line_data_length);
    bp = 0;
    list_statement();
    ASSERT_MEMORY_EQ(buffer, expect_buffer, strlen(expect_buffer));
    ASSERT_EQ(bp, strlen(expect_buffer));
}

static void test_list_statment(void) {

    const char line_data_1[] = { ST_RUN };
    const char line_data_2[] = { ST_LET, 0x80, TOKEN_NUM, 0x00, 0x00, 0xFE, 0x7F, 141, TOKEN_NO_VALUE };
    const char line_data_3[] = { ST_LIST, TOKEN_NUM, 0x00, 0x00, 0x00, 0x20, 130, TOKEN_NO_VALUE, 
        TOKEN_NUM, 0x00, 0x00, 0x00, 0x20, 131, TOKEN_NO_VALUE };
    const char line_data_4[] = { ST_LIST, TOKEN_NUM, 0x00, 0x00, 0x00, 0x20, 130, TOKEN_NO_VALUE, TOKEN_NO_VALUE };
    const char line_data_5[] = { ST_LIST, TOKEN_NO_VALUE, TOKEN_NO_VALUE };
    const char line_data_6[] = { ST_INPUT, 0x80, 0x81, TOKEN_NO_VALUE };
    const char line_data_7[] = { ST_ON_GOTO, 0x80, TOKEN_NO_VALUE, TOKEN_NUM, 0x00, 0x00, 0x00, 0x20, 130, 
        TOKEN_NUM, 0x00, 0x00, 0x00, 0x20, 131, TOKEN_NO_VALUE };
    
    const char list_1[] = "RUN";
    const char list_2[] = "LET X=32767";
    const char list_3[] = "LIST 10,20";
    const char list_4[] = "LIST 10";
    const char list_5[] = "LIST";
    const char list_6[] = "INPUT X,Y";
    const char list_7[] = "ON X GOTO 10,20";

    PRINT_TEST_NAME();

    initialize_program();
    create_variables();

    call_list_statement(line_data_1, sizeof line_data_1, list_1, __LINE__);
    call_list_statement(line_data_2, sizeof line_data_2, list_2, __LINE__);
    call_list_statement(line_data_3, sizeof line_data_3, list_3, __LINE__);
    call_list_statement(line_data_4, sizeof line_data_4, list_4, __LINE__);
    call_list_statement(line_data_5, sizeof line_data_5, list_5, __LINE__);
    call_list_statement(line_data_6, sizeof line_data_6, list_6, __LINE__);
    call_list_statement(line_data_7, sizeof line_data_7, list_7, __LINE__);
}

static void test_list_line(void) {

    const char line_data_1[] = { ST_PRINT, TOKEN_NUM, 0x00, 0x00, 0x80, 0x00, 135, TOKEN_NO_VALUE };
    const char line_data_2[] = { ST_LET, 0x80, TOKEN_NUM, 0x00, 0x00, 0xFE, 0x7F, 141, TOKEN_NO_VALUE };
    const char line_data_end[] = { ST_END };
    
    const char list_1[] = "10 PRINT 257";
    const char list_2[] = "400 LET X=32767";

    PRINT_TEST_NAME();

    initialize_program();
    create_variables();

    set_line(10, line_data_1, sizeof line_data_1);
    list_line();
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(buffer, list_1, sizeof list_1 - 1);
    ASSERT_EQ(bp, sizeof list_1 - 1);

    set_line(400, line_data_2, sizeof line_data_2);
    list_line();
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(buffer, list_2, sizeof list_2 - 1);
    ASSERT_EQ(bp, sizeof list_2 - 1);

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
