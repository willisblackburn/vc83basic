#include "test.h"

void test_is_name_character() {
    int err;

    PRINT_TEST_NAME();

    err = is_name_character('$');
    ASSERT_EQ(err, 0);
    err = is_name_character('A');
    ASSERT_EQ(err, 0);
    err = is_name_character('Z');
    ASSERT_EQ(err, 0);
    err = is_name_character('0');
    ASSERT_EQ(err, 0);
    err = is_name_character('9');
    ASSERT_EQ(err, 0);
    err = is_name_character('#');
    ASSERT_NE(err, 0);
    err = is_name_character('%');
    ASSERT_NE(err, 0);
    err = is_name_character('@');
    ASSERT_NE(err, 0);
    err = is_name_character('[');
    ASSERT_NE(err, 0);
    err = is_name_character('/');
    ASSERT_NE(err, 0);
    err = is_name_character(':');
    ASSERT_NE(err, 0);
    err = is_name_character(' ');
    ASSERT_NE(err, 0);
    err = is_name_character(0);
    ASSERT_NE(err, 0);
    err = is_name_character(0x7F);
    ASSERT_NE(err, 0);
    err = is_name_character(0x80);
    ASSERT_NE(err, 0);
    err = is_name_character(0xFF);
    ASSERT_NE(err, 0);
}

void test_find_name(void) {
    int err;
    // C adds a trailing 0 to these strings which terminates the name table.
    const char* name_table_1 = "PRIN\xD4"; // \xD4 = 'T' with bit 7 set
    const char* name_table_2 = "PRIN\xD4LIS\xD4";
    const char* name_table_3 = "LIS\xD4PRIN\xD4";
    const char* name_table_4 = "LIS\xD4PRINT\x11TO\x91";
    const char* name_table_5 = "LIST\x92PRINT\x11TO\x91";
    const char* name_table_6 = "LIS\xD4";
    const char* name_table_7 = "PRINTE\xD2";
    const char* name_table_8 = "LIS\xD4PRINTE\xD2";
    const char* name_table_9 = "PRI\xCE";
    const char* name_table_10 = "LIS\xD4PRI\xCE";

    PRINT_TEST_NAME();

    strcpy(buffer, "PRINT");
    err = find_name(name_table_1, 0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(reg_a, 0);
    ASSERT_EQ(np, 5);
    ASSERT_EQ(bp, 5);
    ASSERT_EQ(name_ptr, name_table_1);
    err = find_name(name_table_2, 0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(reg_a, 0);
    ASSERT_EQ(np, 5);
    ASSERT_EQ(bp, 5);
    ASSERT_EQ(name_ptr, name_table_2);
    err = find_name(name_table_3, 0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(reg_a, 1);
    ASSERT_EQ(np, 5);
    ASSERT_EQ(bp, 5);
    ASSERT_EQ(name_ptr, name_table_3 + 4);

    // Make sure find_name matches and skips names that have some extra data.
    err = find_name(name_table_4, 0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(reg_a, 1);
    ASSERT_EQ(np, 5);
    ASSERT_EQ(bp, 5);
    ASSERT_EQ(name_ptr, name_table_4 + 4);
    err = find_name(name_table_5, 0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(bp, 5);
    ASSERT_EQ(reg_a, 1);
    ASSERT_EQ(np, 5);
    ASSERT_EQ(name_ptr, name_table_5 + 5);

    // Name not found
    err = find_name(name_table_6, 0);
    ASSERT_NE(err, 0);
    ASSERT_EQ(bp, 0);
    ASSERT_EQ(name_ptr, name_table_6 + 4);

    // Name in name table is longer than input namne
    err = find_name(name_table_7, 0);
    ASSERT_NE(err, 0);
    ASSERT_EQ(reg_a, 1);
    ASSERT_EQ(bp, 0);
    ASSERT_EQ(name_ptr, name_table_7 + 7);
    err = find_name(name_table_8, 0);
    ASSERT_NE(err, 0);
    ASSERT_EQ(reg_a, 2);
    ASSERT_EQ(bp, 0);
    ASSERT_EQ(name_ptr, name_table_8 + 11);

    // Input name is longer than name in table
    err = find_name(name_table_9, 0);
    ASSERT_NE(err, 0);
    ASSERT_EQ(bp, 0);
    ASSERT_EQ(name_ptr, name_table_9 + 4);
    err = find_name(name_table_10, 0);
    ASSERT_NE(err, 0);
    ASSERT_EQ(name_ptr, name_table_10 + 8);
    ASSERT_EQ(bp, 0);

    // Read position is not zero
    err = find_name(name_table_1, 2);
    ASSERT_NE(err, 0);
    ASSERT_EQ(bp, 2);
    ASSERT_EQ(name_ptr, name_table_1 + 5);
}

static void test_find_name_operators(void) {
    int err;
    // C adds a trailing 0 to these strings which terminates the name table.
    const char* name_table_1 = ">\xBD"; // \xBD = '=' with bit 7 set
    const char* name_table_2 = "\xBE>\xBD"; // \xBE = '>' with bit 7 set
    const char* name_table_3 = "\xBD>\xBD\xBE";

    PRINT_TEST_NAME();

    strcpy(buffer, ">=");
    err = find_name(name_table_1, 0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(reg_a, 0);
    ASSERT_EQ(np, 2);
    ASSERT_EQ(bp, 2);
    ASSERT_EQ(name_ptr, name_table_1);
    // We expect operators to prefix match; that is, the ">" in ">=" should match first ">"
    err = find_name(name_table_2, 0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(reg_a, 0);
    ASSERT_EQ(np, 1);
    ASSERT_EQ(bp, 1);
    ASSERT_EQ(name_ptr, name_table_2);
    err = find_name(name_table_3, 0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(reg_a, 1);
    ASSERT_EQ(np, 2);
    ASSERT_EQ(bp, 2);
    ASSERT_EQ(name_ptr, name_table_3 + 1);
}

static void test_get_name_table_entry(void) {
    int err;
    const char* name_table = "LIST\x92" "PRIN\xD4" "FOR\x11=\x11TO\x91" "RU\xCE";

    PRINT_TEST_NAME();

    err = get_name_table_entry(name_table, 0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(name_ptr, name_table);

    err = get_name_table_entry(name_table, 1);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(name_ptr, name_table + 5);

    err = get_name_table_entry(name_table, 2);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(name_ptr, name_table + 5 + 5);

    err = get_name_table_entry(name_table, 3);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(name_ptr, name_table + 5 + 5 + 9);
}

static void test_add_variable(void) {
    int err;

    PRINT_TEST_NAME();

    // Call initialize_program to set up variable_name_table_ptr.
    initialize_program();
    ASSERT_EQ(variable_name_table_ptr[0], 0);
    ASSERT_EQ(value_table_ptr, variable_name_table_ptr + 1);

    // add_variable is used after find_name, which sets up name_ptr.
    strcpy(buffer, "X");
    err = find_name(variable_name_table_ptr, 0);
    ASSERT_NE(err, 0);
    err = add_variable();
    ASSERT_EQ(err, 0);
    ASSERT_EQ(reg_a, 0);
    ASSERT_EQ(bp, 1);
    ASSERT_EQ(variable_count, 1);
    ASSERT_EQ(variable_name_table_ptr[0], 'X' | NT_END);
    ASSERT_EQ(variable_name_table_ptr[1], 0);
    ASSERT_EQ(value_table_ptr, variable_name_table_ptr + 2);
    ASSERT_EQ(*(int*)value_table_ptr, 0);
    ASSERT_EQ(free_ptr, (char*)value_table_ptr + 2);

    strcpy(buffer, "Y,Z");
    err = find_name(variable_name_table_ptr, 0);
    ASSERT_NE(err, 0);
    err = add_variable();
    ASSERT_EQ(err, 0);
    ASSERT_EQ(reg_a, 1);
    ASSERT_EQ(bp, 1);
    ASSERT_EQ(variable_count, 2);
    ASSERT_EQ(variable_name_table_ptr[0], 'X' | NT_END);
    ASSERT_EQ(variable_name_table_ptr[1], 'Y' | NT_END);
    ASSERT_EQ(variable_name_table_ptr[2], 0);
    ASSERT_EQ(value_table_ptr, variable_name_table_ptr + 3);
    ASSERT_EQ(free_ptr, (char*)value_table_ptr + 4);
    err = find_name(variable_name_table_ptr, 2);
    ASSERT_NE(err, 0);
    err = add_variable();
    ASSERT_EQ(err, 0);
    ASSERT_EQ(reg_a, 2);
    ASSERT_EQ(bp, 3);
    ASSERT_EQ(variable_count, 3);
    ASSERT_EQ(variable_name_table_ptr[0], 'X' | NT_END);
    ASSERT_EQ(variable_name_table_ptr[1], 'Y' | NT_END);
    ASSERT_EQ(variable_name_table_ptr[2], 'Z' | NT_END);
    ASSERT_EQ(variable_name_table_ptr[3], 0);
    ASSERT_EQ(value_table_ptr, variable_name_table_ptr + 4);
    ASSERT_EQ(free_ptr, (char*)value_table_ptr + 6);
}

int main(void) {
    initialize_target();
    test_is_name_character();
    test_find_name();
    test_find_name_operators();
    test_get_name_table_entry();
    test_add_variable();
    return 0;
}