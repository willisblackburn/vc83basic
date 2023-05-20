#include "test.h"

static void call_find_name(const char* s, const char* name_table, char set_name_bp, char set_bp, char expect_index,
    char expect_np, const char* expect_name_ptr, int line) {        
    char index;
    fprintf(stderr, "  %s:%d: find_name(\"%s\", name_table=%s, name_bp=%d, bp=%d)\n", __FILE__, line, s, name_table,
        set_name_bp, set_bp);
    strcpy(buffer, s);
    name_bp = set_name_bp;
    bp = set_bp;
    index = find_name(name_table);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(index, expect_index);
    ASSERT_EQ(np, expect_np);
    ASSERT_EQ(name_ptr, expect_name_ptr);
    ASSERT_EQ(bp, set_bp);
}

static void call_find_name_fail(const char* s, const char* name_table, char set_name_bp, char set_bp, char expect_index,
    int line) {
    char index;
    fprintf(stderr, "  %s:%d: find_name(\"%s\", name_table=%s, name_bp=%d, bp=%d)\n", __FILE__, line, s, name_table,
        set_name_bp, set_bp);
    strcpy(buffer, s);
    name_bp = set_name_bp;
    bp = set_bp;
    index = find_name(name_table);
    ASSERT_NE(err, 0);
    ASSERT_EQ(index, expect_index);
    // On fail name_ptr should always point to 0 at the end of the name table (automatically added by C string).
    ASSERT_EQ(name_ptr, name_ptr + strlen(name_ptr));
    ASSERT_EQ(bp, set_bp);
}

static void test_find_name(void) {

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

    call_find_name("PRINT", name_table_1, 0, 5, 0, 5, name_table_1, __LINE__);
    call_find_name("PRINT", name_table_2, 0, 5, 0, 5, name_table_2, __LINE__);
    call_find_name("PRINT", name_table_3, 0, 5, 1, 5, name_table_3 + 4, __LINE__);

    call_find_name("PRINT", name_table_4, 0, 5, 1, 5, name_table_4 + 4, __LINE__);
    call_find_name("PRINT", name_table_5, 0, 5, 1, 5, name_table_5 + 5, __LINE__);

    // Name not found
    call_find_name_fail("PRINT", name_table_6, 0, 5, 1, __LINE__);

    // Name in name table is longer than input namne
    call_find_name_fail("PRINT", name_table_7, 0, 5, 1, __LINE__);
    call_find_name_fail("PRINT", name_table_8, 0, 5, 2, __LINE__);

    // // Input name is longer than name in table
    call_find_name_fail("PRINT", name_table_9, 0, 5, 1, __LINE__);
    call_find_name_fail("PRINT", name_table_10, 0, 5, 2, __LINE__);

    // Name does not start at position 0
    call_find_name_fail("PRINT", name_table_1, 1, 5, 1, __LINE__);

    // Make sure find_name ignores name after bp
    call_find_name_fail("PRINT", name_table_1, 0, 4, 1, __LINE__);
}

static void test_find_name_operators(void) {

    // C adds a trailing 0 to these strings which terminates the name table.
    const char* name_table_1 = ">\xBD"; // \xBD = '=' with bit 7 set
    const char* name_table_2 = "\xBE>\xBD"; // \xBE = '>' with bit 7 set
    const char* name_table_3 = "\xBD>\xBD\xBE";

    PRINT_TEST_NAME();

    call_find_name(">=", name_table_1, 0, 2, 0, 2, name_table_1, __LINE__);
    call_find_name(">=", name_table_2, 0, 2, 1, 2, name_table_2 + 1, __LINE__);
    call_find_name(">", name_table_2, 0, 1, 0, 1, name_table_2, __LINE__);
    call_find_name(">=", name_table_3, 0, 2, 1, 2, name_table_3 + 1, __LINE__);
    call_find_name(">", name_table_3, 0, 1, 2, 1, name_table_3 + 3, __LINE__);
}

static void test_get_name_table_entry(void) {

    const char* name_table = "LIST\x92" "PRIN\xD4" "FOR\x11=\x11TO\x91" "RU\xCE";

    PRINT_TEST_NAME();

    get_name_table_entry(name_table, 0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(name_ptr, name_table);

    get_name_table_entry(name_table, 1);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(name_ptr, name_table + 5);

    get_name_table_entry(name_table, 2);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(name_ptr, name_table + 5 + 5);

    get_name_table_entry(name_table, 3);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(name_ptr, name_table + 5 + 5 + 9);
}

static void test_add_variable(void) {
    char index;

    PRINT_TEST_NAME();

    // Call initialize_program to set up variable_name_table_ptr.
    initialize_program();
    ASSERT_EQ(variable_name_table_ptr[0], 0);
    ASSERT_EQ(value_table_ptr, variable_name_table_ptr + 1);

    // add_variable is used after find_name, which sets up name_ptr.
    strcpy(buffer, "X");
    name_bp = 0;
    bp = 1;
    find_name(variable_name_table_ptr);
    ASSERT_NE(err, 0);
    index = add_variable();
    ASSERT_EQ(err, 0);
    ASSERT_EQ(index, 0);
    ASSERT_EQ(bp, 1);
    ASSERT_EQ(variable_count, 1);
    ASSERT_EQ(variable_name_table_ptr[0], 'X' | NT_END);
    ASSERT_EQ(variable_name_table_ptr[1], 0);
    ASSERT_EQ(value_table_ptr, variable_name_table_ptr + 2);
    ASSERT_EQ(*(int*)value_table_ptr, 0);
    ASSERT_EQ(free_ptr, (char*)value_table_ptr + 2);

    strcpy(buffer, "Y,Z");
    name_bp = 0;
    bp = 1;
    find_name(variable_name_table_ptr);
    ASSERT_NE(err, 0);
    index = add_variable();
    ASSERT_EQ(err, 0);
    ASSERT_EQ(index, 1);
    ASSERT_EQ(bp, 1);
    ASSERT_EQ(variable_count, 2);
    ASSERT_EQ(variable_name_table_ptr[0], 'X' | NT_END);
    ASSERT_EQ(variable_name_table_ptr[1], 'Y' | NT_END);
    ASSERT_EQ(variable_name_table_ptr[2], 0);
    ASSERT_EQ(value_table_ptr, variable_name_table_ptr + 3);
    ASSERT_EQ(free_ptr, (char*)value_table_ptr + 4);
    name_bp = 2;
    bp = 3;
    find_name(variable_name_table_ptr);
    ASSERT_NE(err, 0);
    index = add_variable();
    ASSERT_EQ(err, 0);
    ASSERT_EQ(index, 2);
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
    test_find_name();
    test_find_name_operators();
    test_get_name_table_entry();
    test_add_variable();
    return 0;
}