#include "test.h"

static void test_add_whitespace(void) {

    PRINT_TEST_NAME();

    buffer[0] = 0;
    add_whitespace(0);
    ASSERT_EQ(w, 0);
    ASSERT_EQ(buffer[0], 0);

    buffer[0] = 'X';
    add_whitespace(1);
    ASSERT_EQ(w, 2);
    ASSERT_EQ(buffer[0], 'X');
    ASSERT_EQ(buffer[1], ' ');
}

static void test_list_element(void) {
    // TODO: just use the built-in statement name table.
    const char name_table[] = { 
        'S', 'T', 'O', 'P'+0x80, 
        'P', 'R', 'I', 'N', 'T', 0x91,
        'L', 'E', 'T', 0x11, '=', 0x91
    } ;
    const char line_data_1[] = { 0x02, 0x01, 0x01 };
    const char line_data_2[] = { 0x00 };
    const char line_data_3[] = { 0x80, 0x02, 0x01, 0x00 };
    const char line_text_1[] = { 'P', 'R', 'I', 'N', 'T', ' ', '2', '5', '7' };
    const char line_text_2[] = { 'S', 'T', 'O', 'P', };
    const char line_text_3[] = { 'L', 'E', 'T', ' ', 'X', '=', '1' };

    PRINT_TEST_NAME();

    // Initialize the program memory
    initialize_program();
    // Add the variable name X
    strcpy(buffer, "X");
    find_name(variable_name_table_ptr, 0);
    add_variable();

    list_element(name_table, 1, line_data_1, 0, 0);
    ASSERT_MEMORY_EQ(buffer, line_text_1, sizeof line_text_1);
    ASSERT_EQ(w, 9);

    list_element(name_table, 0, line_data_2, 0, 0);
    ASSERT_MEMORY_EQ(buffer, line_text_2, sizeof line_text_2);
    ASSERT_EQ(w, 4);

    list_element(name_table, 2, line_data_3, 0, 0);
    ASSERT_MEMORY_EQ(buffer, line_text_3, sizeof line_text_3);
    ASSERT_EQ(w, 7);
}

static void test_list_line(void) {
    const char line_data[] = { 0x08, 0x0A, 0x00, 0x03, 0x80, 0x02, 0x01, 0x00 };
    const char line_text[] = { '1', '0', ' ', 'L', 'E', 'T', ' ', 'X', '=', '1' };

    PRINT_TEST_NAME();

    // Initialize the program memory
    initialize_program();
    // Add the variable name X
    strcpy(buffer, "X");
    find_name(variable_name_table_ptr, 0);
    add_variable();

    list_line(line_data);
    ASSERT_MEMORY_EQ(buffer, line_text, sizeof line_text);
    ASSERT_EQ(w, 10);
}

int main(void) {
    initialize_target();
    test_add_whitespace();
    test_list_element();
    test_list_line();
    return 0;
}