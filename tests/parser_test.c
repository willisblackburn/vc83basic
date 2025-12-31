#include "test.h"

void call_parse_pvm(const char* s, const char* start, const char* expect_line_data, size_t expect_line_data_length, int line) {
    size_t expect_buffer_pos;
    fprintf(stderr, "  %s:%d: parse_statements(\"%s\")\n", __FILE__, line, s);
    expect_buffer_pos = strlen(s);
    strcpy(buffer, s);
    buffer_pos = 0;
    line_pos = offsetof(Line, data);
    parse_pvm(start);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(buffer_pos, expect_buffer_pos);
    ASSERT_MEMORY_EQ(line_buffer.data, expect_line_data, expect_line_data_length);
    ASSERT_EQ(line_pos, offsetof(Line, data) + expect_line_data_length);
}

void test_pvm_expression(void) {

    const char line_data_1[] = { '1' };

    PRINT_TEST_NAME();

    // Simple statement (covers all single-keyword statements)
    call_parse_pvm("1", pvm_expression, line_data_1, sizeof line_data_1, __LINE__);


}

void test_pvm_statements(void) {

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
    const char for_line_data_1[] = { ST_FOR, 'X' | EOT, '=', '1', TOKEN_MISC | MISC_TO, '5', 0 };
    const char for_line_data_2[] = { ST_FOR, 'X' | EOT, '=', '1', TOKEN_MISC | MISC_TO, '2', '0', TOKEN_MISC | MISC_STEP, '2', 0 };
    const char let_line_data_1[] = { ST_LET, 'X' | EOT, '=', '1', '0', '0', 0 };
    const char if_line_data_1[] = { ST_IF_THEN, 'X' | EOT, TOKEN_OP | OP_EQ, '1', TOKEN_MISC | MISC_THEN, ST_GOTO, '1', '0', 0 };
    const char input_line_data_1[] = { ST_INPUT, 'A' | EOT, 0 };
    const char input_line_data_2[] = { ST_INPUT, 'A' | EOT, ',', 'B' | EOT, ',', 'C' | EOT, 0 };
    const char on_line_data_1[] = { ST_ON, '1', TOKEN_MISC | MISC_GOTO, '1', '0', 0 };
    const char on_line_data_2[] = { ST_ON, '1', TOKEN_MISC | MISC_GOSUB, '1', '0', 0 };
    const char on_line_data_3[] = { ST_ON, 'X' | EOT, TOKEN_MISC | MISC_GOSUB, '1', '0', ',', '2', '0', ',', '3', '0', 0 };
    const char next_line_data_1[] = { ST_NEXT, 'X' | EOT, 0 };
    const char list_line_data_1[] = { ST_LIST, 0 };
    const char list_line_data_2[] = { ST_LIST, '1', '0', '0', 0 };
    const char list_line_data_3[] = { ST_LIST, '1', '0', '0', ',', '5', '0', '0', 0 };
    const char data_line_data_1[] = { ST_DATA, 'H', 'E', 'L', 'L', 'O', ',', '\"', 'X', ',', 'Y', '\"', ',', '5', 0 };
    const char multi_line_data_1[] = { ST_LET, 'X' | EOT, '=', '1', '0', '0', TOKEN_MISC | MISC_STATEMENT, ST_PRINT, 'X' | EOT, 0 };

    PRINT_TEST_NAME();

    // // Simple statement (covers all single-keyword statements)
    // call_parse_pvm("RUN", simple_line_data_1, sizeof simple_line_data_1, __LINE__);

    // // Number
    // call_parse_pvm("PRINT 1", number_line_data_1, sizeof number_line_data_1, __LINE__);
    // call_parse_pvm("PRINT 25", number_line_data_2, sizeof number_line_data_2, __LINE__);
    // call_parse_pvm("PRINT 3.14159", number_line_data_3, sizeof number_line_data_3, __LINE__);
    // call_parse_pvm("PRINT 10.", number_line_data_4, sizeof number_line_data_4, __LINE__);
    // call_parse_pvm("PRINT .125", number_line_data_5, sizeof number_line_data_5, __LINE__);

    // // String
    // call_parse_pvm("PRINT \"HELLO\"", string_line_data_1, sizeof string_line_data_1, __LINE__);
    // call_parse_pvm("PRINT \"BUG OR \"\"FEATURE?\"\"\"", string_line_data_2, sizeof string_line_data_2, __LINE__);

    // // Variable
    // call_parse_pvm("PRINT IDX_2", variable_line_data_1, sizeof variable_line_data_1, __LINE__);
    // call_parse_pvm("PRINT A$", variable_line_data_2, sizeof variable_line_data_2, __LINE__);
    // call_parse_pvm("PRINT X(5)", variable_line_data_3, sizeof variable_line_data_3, __LINE__);
    // call_parse_pvm("PRINT XYZZY$(1,10)", variable_line_data_4, sizeof variable_line_data_4, __LINE__);

    // // Function
    // call_parse_pvm("PRINT LEN(\"HELLO\")", function_line_data_1, sizeof function_line_data_1, __LINE__);
    // call_parse_pvm("PRINT MID$(\"HELLO\",2,3)", function_line_data_2, sizeof function_line_data_2, __LINE__);

    // // Expression
    // call_parse_pvm("PRINT 1+1+1", expression_line_data_1, sizeof expression_line_data_1, __LINE__);
    // call_parse_pvm("PRINT 1+(1+1)", expression_line_data_2, sizeof expression_line_data_2, __LINE__);
    // call_parse_pvm("PRINT \"HELLO\"&\", WORLD\"", expression_line_data_3, sizeof expression_line_data_3, __LINE__);

    // // FOR
    // call_parse_pvm("FOR X=1 TO 5", for_line_data_1, sizeof for_line_data_1, __LINE__);
    // call_parse_pvm("FOR X=1 TO 20 STEP 2", for_line_data_2, sizeof for_line_data_2, __LINE__);

    // // LET
    // call_parse_pvm("LET X=100", let_line_data_1, sizeof let_line_data_1, __LINE__);

    // // IF
    // call_parse_pvm("IF X=1 THEN GOTO 10", if_line_data_1, sizeof if_line_data_1, __LINE__);

    // // INPUT (covers READ)
    // call_parse_pvm("INPUT A", input_line_data_1, sizeof input_line_data_1, __LINE__);
    // call_parse_pvm("INPUT A,B,C", input_line_data_2, sizeof input_line_data_2, __LINE__);

    // // ON
    // call_parse_pvm("ON 1 GOTO 10", on_line_data_1, sizeof on_line_data_1, __LINE__);
    // call_parse_pvm("ON 1 GOSUB 10", on_line_data_2, sizeof on_line_data_2, __LINE__);
    // call_parse_pvm("ON X GOSUB 10,20,30", on_line_data_3, sizeof on_line_data_3, __LINE__);

    // // NEXT
    // call_parse_pvm("NEXT X", next_line_data_1, sizeof next_line_data_1, __LINE__);

    // // LIST
    // call_parse_pvm("LIST", list_line_data_1, sizeof list_line_data_1, __LINE__);
    // call_parse_pvm("LIST 100", list_line_data_2, sizeof list_line_data_2, __LINE__);
    // call_parse_pvm("LIST 100,500", list_line_data_3, sizeof list_line_data_3, __LINE__);

    // // DATA
    // call_parse_pvm("DATA HELLO,\"X,Y\",5", data_line_data_1, sizeof data_line_data_1, __LINE__);

    // // Multiple statements
    // call_parse_pvm("LET X=100:PRINT X", multi_line_data_1, sizeof multi_line_data_1, __LINE__);
}

int main(void) {
    initialize_target();
    test_pvm_expression();
    test_pvm_statements();
    return 0;
}