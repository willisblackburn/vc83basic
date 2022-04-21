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

void test_match_character_sequence() {
    int err;

    PRINT_TEST_NAME();

    set_buffer("PRINT");
    err = match_character_sequence("PRIN\xD4", 0, 0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(reg_y, 5);
    ASSERT_EQ(r, 5);
    err = match_character_sequence("PRINT\x11", 0, 0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(reg_y, 5);
    ASSERT_EQ(r, 5);

    set_buffer("LET X=1");
    err = match_character_sequence("LET\x11=\x91", 4, 5);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(reg_y, 5);
    ASSERT_EQ(r, 6);
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

    set_buffer("PRINT");
    err = find_name(name_table_1, 0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(reg_a, 0);
    ASSERT_EQ(reg_y, 5);
    ASSERT_EQ(r, 5);
    ASSERT_EQ(name_ptr, name_table_1);
    err = find_name(name_table_2, 0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(reg_a, 0);
    ASSERT_EQ(reg_y, 5);
    ASSERT_EQ(r, 5);
    ASSERT_EQ(name_ptr, name_table_2);
    err = find_name(name_table_3, 0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(reg_a, 1);
    ASSERT_EQ(reg_y, 5);
    ASSERT_EQ(r, 5);
    ASSERT_EQ(name_ptr, name_table_3 + 4);

    // Make sure find_name matches and skips names that have some extra data.
    err = find_name(name_table_4, 0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(reg_a, 1);
    ASSERT_EQ(reg_y, 5);
    ASSERT_EQ(r, 5);
    ASSERT_EQ(name_ptr, name_table_4 + 4);
    err = find_name(name_table_5, 0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(r, 5);
    ASSERT_EQ(reg_a, 1);
    ASSERT_EQ(reg_y, 5);
    ASSERT_EQ(name_ptr, name_table_5 + 5);

    // Name not found
    err = find_name(name_table_6, 0);
    ASSERT_NE(err, 0);
    ASSERT_EQ(r, 0);
    ASSERT_EQ(name_ptr, name_table_6 + 4);

    // Name in name table is longer than input namne
    err = find_name(name_table_7, 0);
    ASSERT_NE(err, 0);
    ASSERT_EQ(reg_a, 1);
    ASSERT_EQ(r, 0);
    ASSERT_EQ(name_ptr, name_table_7 + 7);
    err = find_name(name_table_8, 0);
    ASSERT_NE(err, 0);
    ASSERT_EQ(reg_a, 2);
    ASSERT_EQ(r, 0);
    ASSERT_EQ(name_ptr, name_table_8 + 11);

    // Input name is longer than name in table
    err = find_name(name_table_9, 0);
    ASSERT_NE(err, 0);
    ASSERT_EQ(r, 0);
    ASSERT_EQ(name_ptr, name_table_9 + 4);
    err = find_name(name_table_10, 0);
    ASSERT_NE(err, 0);
    ASSERT_EQ(name_ptr, name_table_10 + 8);
    ASSERT_EQ(r, 0);

    // Read position is not zero
    err = find_name(name_table_1, 2);
    ASSERT_NE(err, 0);
    ASSERT_EQ(r, 2);
    ASSERT_EQ(name_ptr, name_table_1 + 5);
}

static void test_find_name_operators(void) {
    int err;
    // C adds a trailing 0 to these strings which terminates the name table.
    const char* name_table_1 = ">\xBD"; // \xBD = '=' with bit 7 set
    const char* name_table_2 = "\xBE>\xBD"; // \xBE = '>' with bit 7 set
    const char* name_table_3 = "\xBD>\xBD\xBE";

    PRINT_TEST_NAME();

    set_buffer(">=");
    err = find_name(name_table_1, 0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(reg_a, 0);
    ASSERT_EQ(reg_y, 2);
    ASSERT_EQ(r, 2);
    ASSERT_EQ(name_ptr, name_table_1);
    // We expect operators to prefix match; that is, the ">" in ">=" should match first ">"
    err = find_name(name_table_2, 0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(reg_a, 0);
    ASSERT_EQ(reg_y, 1);
    ASSERT_EQ(r, 1);
    ASSERT_EQ(name_ptr, name_table_2);
    err = find_name(name_table_3, 0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(reg_a, 1);
    ASSERT_EQ(reg_y, 2);
    ASSERT_EQ(r, 2);
    ASSERT_EQ(name_ptr, name_table_3 + 1);
}

static void test_add_variable(void) {
    int err;

    PRINT_TEST_NAME();

    // Call initialize_program to set up variable_name_table_ptr.
    initialize_program();
    ASSERT_EQ(*variable_name_table_ptr, 0);

    // add_variable is used after find_name, which sets up name_ptr and r.
    set_buffer("X");
    err = find_name(variable_name_table_ptr, 0);
    ASSERT_NE(err, 0);
    err = add_variable();
    ASSERT_EQ(err, 0);
    ASSERT_EQ(reg_a, 0);
    ASSERT_EQ(r, 1);
    ASSERT_EQ(variable_count, 1);
}

int main(void) {
    initialize_target();
    test_is_name_character();
    test_match_character_sequence();
    test_find_name();
    test_find_name_operators();
    test_add_variable();
    return 0;
}