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
    ASSERT_EQ(r, 2);

    // The function should honor the current read position.
    strcpy(buffer, "1020 PRINT X");
    err = read_number(2);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(reg_ax, 20);
    ASSERT_EQ(r, 4);

    // The function should return carry set if an invalid number.
    strcpy(buffer, "invalid");
    err = read_number(0);
    ASSERT_NE(err, 0);
    ASSERT_EQ(r, 0);

    strcpy(buffer, "");
    err = read_number(0);
    ASSERT_NE(err, 0);
    ASSERT_EQ(r, 0);
}

static void test_parse_expression(void) {
    int err;
    
    const char line_data_1[] = { 0x02, 0x01, 0x00 };
    const char line_data_2[] = { 0x80 };

    PRINT_TEST_NAME();

    initialize_program();

    strcpy(buffer, "1");
    err = parse_expression(0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_1, sizeof line_data_1);
    ASSERT_EQ(r, 1);
    ASSERT_EQ(w, offsetof(Line, data) + 3);

    strcpy(buffer, "X");
    err = parse_expression(0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_2, sizeof line_data_2);
    ASSERT_EQ(r, 1);
    ASSERT_EQ(w, offsetof(Line, data) + 1);
}

static void test_parse_argument_separator(void) {
    int err;

    PRINT_TEST_NAME();

    strcpy(buffer, ",");
    err = parse_argument_separator(0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(r, 1);

    strcpy(buffer, "  ,");
    err = parse_argument_separator(0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(r, 3);

    strcpy(buffer, "x");
    err = parse_argument_separator(0);
    ASSERT_NE(err, 0);
    ASSERT_EQ(r, 0);

    strcpy(buffer, ",");
    err = parse_argument_separator(1);
    ASSERT_NE(err, 0);
    ASSERT_EQ(r, 1);
}

static void test_parse_arguments(void) {
    int err;
    char signature_table[] = { 0x01, 0x01 };

    const char line_data_1[] = { 0x02, 0x01, 0x00 };
    const char line_data_2[] = { 0x02, 0x01, 0x00 };
    const char line_data_3[] = { 0x02, 0x01, 0x00, 0x02, 0x00, 0x01 };

    PRINT_TEST_NAME();

    strcpy(buffer, "1");
    err = parse_arguments(1, signature_table, 0, 0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_1, sizeof line_data_1);
    ASSERT_EQ(r, 1);
    ASSERT_EQ(w, offsetof(Line, data) + 3);
    ASSERT_EQ(argument_index, 1);

    strcpy(buffer, "1,");
    err = parse_arguments(1, signature_table, 0, 0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_2, sizeof line_data_2);
    ASSERT_EQ(r, 1);
    ASSERT_EQ(w, offsetof(Line, data) + 3);
    ASSERT_EQ(argument_index, 1);

    strcpy(buffer, " 1, 256");
    err = parse_arguments(2, signature_table, 0, 0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_3, sizeof line_data_3);
    ASSERT_EQ(r, 7);
    ASSERT_EQ(w, offsetof(Line, data) + 6);
    ASSERT_EQ(argument_index, 2);
}

static void test_parse_element(void) {
    int err;
    char name_table[] = { 
        'P', 'L', 'O', 'T', 0x12+0x80, 
        'N', 'E', 'W'+0x80, 
        'G', 'R', 0x11+0x80,
        'F', 'O', 'R', 0x11, 'T', 'O', 0x11+0x80, 
        'L', 'E', 'T', 0x11, '=', 0x11+0x80, 
        0
    };
    char signature_table[] = { 
        0x01, 0x01,
        0, 0, 
        0x01, 0,
        0x01, 0x01,
        0x08, 0x07
    };

    const char line_data_1[] = { 0x00, 0x02, 0x0A, 0x00, 0x02, 0x64, 0x00 };
    const char line_data_2[] = { 0x01 };
    const char line_data_3[] = { 0x02, 0x02, 0x08, 0x00 };
    const char line_data_4[] = { 0x03, 0x02, 0x01, 0x00, 0x02, 0x10, 0x27 };
    const char line_data_5[] = { 0x04, 0x80, 0x02, 0x64, 0x00 };

    PRINT_TEST_NAME();

    strcpy(buffer, "PLOT 10,100");
    err = parse_element(name_table, signature_table, 0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_1, sizeof line_data_1);
    ASSERT_EQ(r, 11);
    ASSERT_EQ(w, offsetof(Line, data) + 7);

    strcpy(buffer, "NEW");
    err = parse_element(name_table, signature_table, 0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_2, sizeof line_data_2);
    ASSERT_EQ(r, 3);
    ASSERT_EQ(w, offsetof(Line, data) + 1);

    strcpy(buffer, "GR 8");
    err = parse_element(name_table, signature_table, 0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_3, sizeof line_data_3);
    ASSERT_EQ(r, 4);
    ASSERT_EQ(w, offsetof(Line, data) + 4);

    strcpy(buffer, "FOR 1 TO 10000");
    err = parse_element(name_table, signature_table, 0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_4, sizeof line_data_4);
    ASSERT_EQ(r, 14);
    ASSERT_EQ(w, offsetof(Line, data) + 7);

    strcpy(buffer, "LET X=100");
    err = parse_element(name_table, signature_table, 0, offsetof(Line, data));
    ASSERT_EQ(err, 0);
    ASSERT_MEMORY_EQ(line_buffer.data, line_data_5, sizeof line_data_5);
    ASSERT_EQ(r, 9);
    ASSERT_EQ(w, offsetof(Line, data) + 5);
}

int main(void) {
    initialize_target();
    test_char_to_digit();
    test_read_number();
    test_parse_expression();
    test_parse_argument_separator();
    test_parse_arguments();
    test_parse_element();
    return 0;
}