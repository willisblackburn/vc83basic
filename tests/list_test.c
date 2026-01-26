#include "test.h"

void call_list_statement(const char* line_data, size_t line_data_length, const char* expect_buffer, int line) {
    fprintf(stderr, "  %s:%d: list_statement(): expecting \"%s\"\n", __FILE__, line, expect_buffer);
    set_line(0, line_data, line_data_length);
    buffer_pos = 0;
    list_statement();
    ASSERT_MEMORY_EQ(buffer, expect_buffer, strlen(expect_buffer));
    ASSERT_EQ(buffer_pos, strlen(expect_buffer));
}

void test_list_statement(void) {

    // The test cases here should mirror the ones in parser_test.c.

    const char simple_line_data_1[] = { ST_RUN, 0 };
    const char number_line_data_1[] = { ST_PRINT, '1', 0 };
    const char number_line_data_2[] = { ST_PRINT, '2', '5', 0 };
    const char number_line_data_3[] = { ST_PRINT, '3', '.', '1', '4', '1', '5', '9', 0 };
    const char number_line_data_4[] = { ST_PRINT, '1', '0', '.', 0 };
    const char number_line_data_5[] = { ST_PRINT, '.', '1', '2', '5', 0 };
    const char string_line_data_1[] = { ST_PRINT, '"', 'H', 'E', 'L', 'L', 'O', '"', 0 };
    const char string_line_data_2[] = { ST_PRINT, '"', 'B', 'U', 'G', ' ', 'O', 'R', ' ', '"', '"', 
        'F', 'E', 'A', 'T', 'U', 'R', 'E', '?', '"', '"', '"', 0 };
    const char variable_line_data_1[] = { ST_PRINT, 'I', 'D', 'X', '_', '2' | EOT, 0 };
    const char variable_line_data_2[] = { ST_PRINT, 'A', '$' | EOT, 0 };
    const char variable_line_data_3[] = { ST_PRINT, 'X' | EOT, '(', '5', ')', 0 };
    const char variable_line_data_4[] = { ST_PRINT, 'X', 'Y', 'Z', 'Z', 'Y', '$' | EOT, '(', '1', ',', '1', '0', ')', 0 };
    const char function_line_data_1[] = { ST_PRINT, TOKEN_FUNCTION | 0, '(', '"', 'H', 'E', 'L', 'L', 'O', '"', ')', 0 };
    const char function_line_data_2[] = { ST_PRINT, TOKEN_FUNCTION | 6, '(', '"', 'H', 'E', 'L', 'L', 'O', '"', ',', '2', ',', '3', ')', 0 };
    const char expression_line_data_1[] = { ST_PRINT, '1', TOKEN_OP | OP_ADD, '1', TOKEN_OP | OP_ADD, '1', 0 };
    const char expression_line_data_2[] = { ST_PRINT, '1', TOKEN_OP | OP_ADD, '(', '1', TOKEN_OP | OP_ADD, '1', ')', 0 };
    const char expression_line_data_3[] = { ST_PRINT, '"', 'H', 'E', 'L', 'L', 'O', '"', TOKEN_OP | OP_CONCAT, '"', ',', ' ', 'W', 'O', 'R', 'L', 'D', '"', 0 };
    const char for_line_data_1[] = { ST_FOR, 'X' | EOT, '=', '1', TOKEN_CLAUSE | CLAUSE_TO, '5', 0 };
    const char for_line_data_2[] = { ST_FOR, 'X' | EOT, '=', '1', TOKEN_CLAUSE | CLAUSE_TO, '2', '0', TOKEN_CLAUSE | CLAUSE_STEP, '2', 0 };
    const char let_line_data_1[] = { ST_LET, 'X' | EOT, '=', '1', '0', '0', 0 };
    const char if_line_data_1[] = { ST_IF_THEN, 'X' | EOT, TOKEN_OP | OP_EQ, '1', TOKEN_CLAUSE | CLAUSE_THEN, ST_GOTO, '1', '0', 0 };
    const char input_line_data_1[] = { ST_INPUT, 'A' | EOT, 0 };
    const char input_line_data_2[] = { ST_INPUT, 'A' | EOT, ',', 'B' | EOT, ',', 'C' | EOT, 0 };
    const char on_line_data_1[] = { ST_ON, '1', TOKEN_CLAUSE | CLAUSE_GOTO, '1', '0', 0 };
    const char on_line_data_2[] = { ST_ON, '1', TOKEN_CLAUSE | CLAUSE_GOSUB, '1', '0', 0 };
    const char on_line_data_3[] = { ST_ON, 'X' | EOT, TOKEN_CLAUSE | CLAUSE_GOSUB, '1', '0', ',', '2', '0', ',', '3', '0', 0 };
    const char next_line_data_1[] = { ST_NEXT, 'X' | EOT, 0 };
    const char list_line_data_1[] = { ST_LIST, 0 };
    const char list_line_data_2[] = { ST_LIST, '1', '0', '0', 0 };
    const char list_line_data_3[] = { ST_LIST, '1', '0', '0', ',', '5', '0', '0', 0 };
    const char data_line_data_1[] = { ST_DATA, 'H', 'E', 'L', 'L', 'O', ',', '\"', 'X', ',', 'Y', '\"', ',', '5', 0 };
    // const char multi_line_data_1[] = { ST_LET, 'X' | EOT, '=', '1', '0', '0', TOKEN_CLAUSE | CLAUSE_STATEMENT, ST_PRINT, 'X' | EOT, 0 };

    PRINT_TEST_NAME();

    initialize_program();

    call_list_statement(simple_line_data_1, sizeof simple_line_data_1, "RUN", __LINE__);
    call_list_statement(number_line_data_1, sizeof number_line_data_1, "PRINT 1", __LINE__);
    call_list_statement(number_line_data_2, sizeof number_line_data_2, "PRINT 25", __LINE__);
    call_list_statement(number_line_data_3, sizeof number_line_data_3, "PRINT 3.14159", __LINE__);
    call_list_statement(number_line_data_4, sizeof number_line_data_4, "PRINT 10.", __LINE__);
    call_list_statement(number_line_data_5, sizeof number_line_data_5, "PRINT .125", __LINE__);
    call_list_statement(string_line_data_1, sizeof string_line_data_1, "PRINT \"HELLO\"", __LINE__);
    call_list_statement(string_line_data_2, sizeof string_line_data_2, "PRINT \"BUG OR \"\"FEATURE?\"\"\"", __LINE__);
    call_list_statement(variable_line_data_1, sizeof variable_line_data_1, "PRINT IDX_2", __LINE__);
    call_list_statement(variable_line_data_2, sizeof variable_line_data_2, "PRINT A$", __LINE__);
    call_list_statement(variable_line_data_3, sizeof variable_line_data_3, "PRINT X(5)", __LINE__);
    call_list_statement(variable_line_data_4, sizeof variable_line_data_4, "PRINT XYZZY$(1,10)", __LINE__);
    call_list_statement(function_line_data_1, sizeof function_line_data_1, "PRINT LEN(\"HELLO\")", __LINE__);
    call_list_statement(function_line_data_2, sizeof function_line_data_2, "PRINT MID$(\"HELLO\",2,3)", __LINE__);
    call_list_statement(expression_line_data_1, sizeof expression_line_data_1, "PRINT 1+1+1", __LINE__);
    call_list_statement(expression_line_data_2, sizeof expression_line_data_2, "PRINT 1+(1+1)", __LINE__);
    call_list_statement(expression_line_data_3, sizeof expression_line_data_3, "PRINT \"HELLO\"&\", WORLD\"", __LINE__);
    call_list_statement(for_line_data_1, sizeof for_line_data_1, "FOR X=1 TO 5", __LINE__);
    call_list_statement(for_line_data_2, sizeof for_line_data_2, "FOR X=1 TO 20 STEP 2", __LINE__);
    call_list_statement(let_line_data_1, sizeof let_line_data_1, "LET X=100", __LINE__);
    call_list_statement(if_line_data_1, sizeof if_line_data_1, "IF X=1 THEN GOTO 10", __LINE__);
    call_list_statement(input_line_data_1, sizeof input_line_data_1, "INPUT A", __LINE__);
    call_list_statement(input_line_data_2, sizeof input_line_data_2, "INPUT A,B,C", __LINE__);
    call_list_statement(on_line_data_1, sizeof on_line_data_1, "ON 1 GOTO 10", __LINE__);
    call_list_statement(on_line_data_2, sizeof on_line_data_2, "ON 1 GOSUB 10", __LINE__);
    call_list_statement(on_line_data_3, sizeof on_line_data_3, "ON X GOSUB 10,20,30", __LINE__);
    call_list_statement(next_line_data_1, sizeof next_line_data_1, "NEXT X", __LINE__);
    call_list_statement(list_line_data_1, sizeof list_line_data_1, "LIST", __LINE__);
    call_list_statement(list_line_data_2, sizeof list_line_data_2, "LIST 100", __LINE__);
    call_list_statement(list_line_data_3, sizeof list_line_data_3, "LIST 100,500", __LINE__);
    call_list_statement(data_line_data_1, sizeof data_line_data_1, "DATA HELLO,\"X,Y\",5", __LINE__);
    // call_list_statement(multi_line_data_1, sizeof multi_line_data_1, "LET X=100:PRINT X", __LINE__);
}

int main(void) {

    initialize_target();
    test_list_statement();

    return 0;
}
