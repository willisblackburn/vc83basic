#include "test.h"

void add_variable_with_name(const char* name) {
    parse_and_decode_name(name);
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
    const char line_data_2[] = { ST_LET, 'X' | EOT, 0, '3', '2', '7', '6', '7', 0 };
    // obsolete 3 and 4
    const char line_data_5[] = { ST_LIST, 0 };
    const char line_data_6[] = { ST_INPUT, 'X' | EOT, ',', 'Y' | EOT, 0 };
    const char line_data_7[] = { ST_PRINT, '(', 'X' | EOT, TOKEN_OP | OP_ADD, '3', ')',
        TOKEN_OP | OP_MUL, 'Y' | EOT, 0 };
    const char line_data_8[] = { ST_PRINT, TOKEN_UNARY_OP | UNARY_OP_MINUS, 'X' | EOT, 0 };
    const char line_data_9[] = { ST_PRINT, '2', '2' | EOT, TOKEN_OP | OP_DIV, '7', 0 };
    const char line_data_10[] = { ST_PRINT, '2', '2' | EOT, TOKEN_OP | OP_DIV, '7', ',',
        TOKEN_UNARY_OP | UNARY_OP_MINUS, 'X' | EOT, 0 };
    const char line_data_11[] = { ST_ON_GOTO, 'X' | EOT, 0, '1', '0', ',', '2', '0', 0 };
    const char line_data_12[] = { ST_PRINT, 'X' | EOT, TOKEN_OP | OP_LE, '7', TOKEN_OP | OP_OR,
        'Y' | EOT, TOKEN_OP | OP_EQ, '4', '1', '1', '2', 0 };
    const char line_data_13[] = { ST_PRINT, '(', 'X' | EOT, TOKEN_OP | OP_ADD, '3', ')',
        TOKEN_OP | OP_AND, 'Y' | EOT, 0 };
    const char line_data_14[] = { ST_PRINT, TOKEN_UNARY_OP | UNARY_OP_NOT, '(', 'X' | EOT, TOKEN_OP | OP_EQ,
        '3', TOKEN_OP | OP_OR, TOKEN_UNARY_OP | UNARY_OP_NOT, TOKEN_UNARY_OP | UNARY_OP_MINUS, 
        'Y' | EOT, ')', 0 };
    const char line_data_15[] = { ST_IF_THEN, 'X' | EOT, TOKEN_OP | OP_LT, '1', '0', 0, ST_PRINT, 'X' | EOT, 0, 0 };
    
    const char list_1[] = "RUN";
    const char list_2[] = "LET X=32767";
    const char list_5[] = "LIST";
    const char list_6[] = "INPUT X,Y";
    const char list_7[] = "PRINT (X+3)*Y";
    const char list_8[] = "PRINT -X";
    const char list_9[] = "PRINT 22/7";
    const char list_10[] = "PRINT 22/7,-X";
    const char list_11[] = "ON X GOTO 10,20";
    const char list_12[] = "PRINT X<=7 OR Y=4112";
    const char list_13[] = "PRINT (X+3) AND Y";
    const char list_14[] = "PRINT NOT (X=3 OR NOT -Y)";
    const char list_15[] = "IF X<10 THEN PRINT X";

    PRINT_TEST_NAME();

    initialize_program();
    create_variables();

    call_list_statement(line_data_1, sizeof line_data_1, list_1, __LINE__);
    call_list_statement(line_data_2, sizeof line_data_2, list_2, __LINE__);
    call_list_statement(line_data_5, sizeof line_data_5, list_5, __LINE__);
    call_list_statement(line_data_6, sizeof line_data_6, list_6, __LINE__);
    call_list_statement(line_data_7, sizeof line_data_7, list_7, __LINE__);
    call_list_statement(line_data_8, sizeof line_data_8, list_8, __LINE__);
    call_list_statement(line_data_9, sizeof line_data_9, list_9, __LINE__);
    call_list_statement(line_data_10, sizeof line_data_10, list_10, __LINE__);
    call_list_statement(line_data_11, sizeof line_data_11, list_11, __LINE__);
    call_list_statement(line_data_12, sizeof line_data_12, list_12, __LINE__);
    call_list_statement(line_data_13, sizeof line_data_13, list_13, __LINE__);
    call_list_statement(line_data_14, sizeof line_data_14, list_14, __LINE__);
    call_list_statement(line_data_15, sizeof line_data_15, list_15, __LINE__);
}

void test_list_line(void) {

    const char line_data_1[] = { 9, ST_PRINT, '2', '5', '7', 0 };
    const char line_data_2[] = { 13, ST_LET, 'X' | EOT, 0, '3', '2', '7', '6', '7', 0 };
    const char line_data_3[] = { 13, ST_LET, 'X' | EOT, 0, '3', '2', '7', '6', '7', 0,
        17, ST_PRINT, 'X' | EOT, 0 };
    
    const char list_1[] = "10 PRINT 257";
    const char list_2[] = "400 LET X=32767";
    const char list_3[] = "400 LET X=32767:PRINT X";

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

    set_line(400, line_data_3, sizeof line_data_3);
    list_line();
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(buffer, list_3, sizeof list_3 - 1);
    ASSERT_EQ(buffer_pos, sizeof list_3 - 1);

    // Test that list_line returns carry set when at the null line:

    line_buffer.number = -1;
    line_buffer.next_line_offset = 0;
    list_line();
    ASSERT_NE(err, 0);
}

int main(void) {

    initialize_target();
    test_list_statment();
    test_list_line();

    return 0;
}
