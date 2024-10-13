#include "test.h"

void test_initialize_name_ptr(void) {

    PRINT_TEST_NAME();

    name_ptr = NULL;
    next_name_ptr = NULL;

    initialize_name_ptr(0xA000);
    ASSERT_PTR_EQ(name_ptr, NULL);
    ASSERT_PTR_EQ(next_name_ptr, 0xA000);
}

void test_advance_name_ptr(void) {

    const char name_table_data[] = { 6, 'L', 'I', 'S', 'T' | NT_STOP, 1, 10, 'P', 'R', 'I', 'N', 'T' | NT_STOP, 1, 
        'T', 'O' | NT_STOP, 1 };
    const char name_table_data_2[] = { 4, 'R', 'U', 'N' | NT_STOP, 0 };
    static char large_name_table[541];

    PRINT_TEST_NAME();

    // Set up the large name table.
    memset(large_name_table, 0, sizeof large_name_table);
    // Use 2 entries from name_table_data: 16 bytes
    memcpy(large_name_table, name_table_data, sizeof name_table_data);
    // Add a large 520-byte variable
    large_name_table[16] = 0x82; // length high byte with high bit set
    large_name_table[17] = 0x08; // length low byte
    large_name_table[18] = 'X' | NT_STOP;
    // Next variable will be at offset 16 + 520 = 536
    memcpy(large_name_table + 536, name_table_data_2, sizeof name_table_data_2);

    // Pre-requisite
    next_name_ptr = large_name_table;

    advance_name_ptr();
    ASSERT_EQ(err, 0);
    ASSERT_EQ(name_ptr, large_name_table + 1);
    ASSERT_EQ(next_name_ptr, large_name_table + 6);
    advance_name_ptr();
    ASSERT_EQ(err, 0);
    ASSERT_EQ(name_ptr, large_name_table + 6 + 1);
    ASSERT_EQ(next_name_ptr, large_name_table + 6 + 10);
    advance_name_ptr();
    ASSERT_EQ(err, 0);
    ASSERT_EQ(name_ptr, large_name_table + 6 + 10 + 2);
    ASSERT_EQ(next_name_ptr, large_name_table + 6 + 10 + 520);
    advance_name_ptr();
    ASSERT_EQ(err, 0);
    ASSERT_EQ(name_ptr, large_name_table + 6 + 10 + 520 + 1);
    ASSERT_EQ(next_name_ptr, large_name_table + 6 + 10 + 520 + 4);
    advance_name_ptr();
    ASSERT_NE(err, 0);
}

void set_match_ptr(const char* name) {
    // Parse given name to set match_ptr and high bit on final character.
    // Also sets match_length, which would normally be set in decode_name.
    strcpy(buffer, name);
    match_ptr = buffer;
    match_length = strlen(buffer);
    buffer[match_length - 1] |= NT_STOP;
}

void call_find_name(const char* name, const char* name_table, char expect_index,
    const char* expect_name_ptr, int line) {        
    char index;
    fprintf(stderr, "  %s:%d: find_name(\"%s\")\n", __FILE__, line, name);
    set_match_ptr(name);
    HEXDUMP(name_table, 32);
    index = find_name(name_table);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(index, expect_index);
    ASSERT_PTR_EQ(name_ptr, expect_name_ptr);
}

void call_find_name_fail(const char* name, const char* name_table, char expect_index,
    const char* expect_name_ptr, int line) {
    char index;
    fprintf(stderr, "  %s:%d: find_name(\"%s\")\n", __FILE__, line, name);
    set_match_ptr(name);
    HEXDUMP(name_table, 32);
    index = find_name(name_table);
    ASSERT_NE(err, 0);
    ASSERT_EQ(index, expect_index);
    // On fail name_ptr should always point to 0 at the end of the name table.
    ASSERT_PTR_EQ(name_ptr, expect_name_ptr);
}

void test_find_name(void) {

    const char name_table_1[] = { 6, 'P', 'R', 'I', 'N', 'T' | NT_STOP, 0 };
    const char name_table_2[] = { 6, 'P', 'R', 'I', 'N', 'T' | NT_STOP, 1, 'X' | NT_STOP, 0 };
    const char name_table_3[] = { 1, 'X' | NT_STOP, 6, 'P', 'R', 'I', 'N', 'T' | NT_STOP, 0 };
    const char name_table_4[] = { 5, 'L', 'I', 'S', 'T' | NT_STOP, 10, 'P', 'R', 'I', 'N', 'T' | NT_STOP, 1, 
        'T', 'O' | NT_STOP, 1, 0 };
    const char name_table_5[] = { 6, 'L', 'I', 'S', 'T' | NT_STOP, 1, 10, 'P', 'R', 'I', 'N', 'T' | NT_STOP, 1, 
        'T', 'O' | NT_STOP, 1, 0 };
    const char name_table_6[] = { 5, 'L', 'I', 'S', 'T' | NT_STOP, 0 };
    const char name_table_7[] = { 8, 'P', 'R', 'I', 'N', 'T', 'E', 'R' | NT_STOP, 0 };
    const char name_table_8[] = { 5, 'L', 'I', 'S', 'T' | NT_STOP, 8, 'P', 'R', 'I', 'N', 'T', 'E', 'R' | NT_STOP, 0 };
    const char name_table_9[] = { 5, 'P', 'R', 'I', 'N' | NT_STOP, 0 };
    const char name_table_10[] = { 5, 'L', 'I', 'S', 'T' | NT_STOP, 5, 'P', 'R', 'I', 'N' | NT_STOP, 0 };

    PRINT_TEST_NAME();

    call_find_name("PRINT", name_table_1, 0, name_table_1 + 6, __LINE__);
    call_find_name("PRINT", name_table_2, 0, name_table_2 + 6, __LINE__);
    call_find_name("X", name_table_2, 1, name_table_2 + 8, __LINE__);
    call_find_name("PRINT", name_table_3, 1, name_table_3 + 8, __LINE__);
    call_find_name("X", name_table_3, 0, name_table_3 + 2, __LINE__);
    call_find_name("PRINT", name_table_4, 1, name_table_4 + 11, __LINE__);
    call_find_name("PRINT", name_table_5, 1, name_table_5 + 12, __LINE__);

    // Name not found
    call_find_name_fail("PRINT", name_table_6, 1, name_table_6 + 5, __LINE__);

    // Name in name table is longer than input namne
    call_find_name_fail("PRINT", name_table_7, 1, name_table_7 + 8, __LINE__);
    call_find_name_fail("PRINT", name_table_8, 2, name_table_8 + 5 + 8, __LINE__);

    // Input name is longer than name in table
    call_find_name_fail("PRINT", name_table_9, 1, name_table_9 + 5, __LINE__);
    call_find_name_fail("PRINT", name_table_10, 2, name_table_10 + 5 + 5, __LINE__);
}

void test_find_name_operators(void) {

    const char name_table_1[] = { 3, '>', '=' | NT_STOP, 0 };
    const char name_table_2[] = { 2, '>' | NT_STOP, 3, '>', '=' | NT_STOP, 0 };
    const char name_table_3[] = { 2, '=' | NT_STOP, 3, '>', '=' | NT_STOP, 2, '>' | NT_STOP, 0 };

    PRINT_TEST_NAME();

    call_find_name(">=", name_table_1, 0, name_table_1 + 3, __LINE__);
    call_find_name(">=", name_table_2, 1, name_table_2 + 5, __LINE__);
    call_find_name(">", name_table_2, 0, name_table_2 + 2, __LINE__);
    call_find_name(">=", name_table_3, 1, name_table_3 + 5, __LINE__);
    call_find_name(">", name_table_3, 2, name_table_3 + 7, __LINE__);
}

void test_add_variable(void) {

    PRINT_TEST_NAME();

    // Call initialize_program to set up variable_name_table_ptr.
    initialize_program();
    ASSERT_EQ(variable_name_table_ptr[0], 0);
    ASSERT_PTR_EQ(free_ptr, variable_name_table_ptr + 1);

    // add_variable is used after find_name, which sets up name_ptr.
    // The call_find_name_fail function sets match_ptr.
    call_find_name_fail("X", variable_name_table_ptr, 0, variable_name_table_ptr, __LINE__);
    add_variable(2);
    HEXDUMP(variable_name_table_ptr, ((char*)free_ptr - variable_name_table_ptr));
    ASSERT_EQ(err, 0);
    ASSERT_EQ(variable_name_table_ptr[0], 4); // length
    ASSERT_EQ(variable_name_table_ptr[1], 'X' | NT_STOP);
    ASSERT_EQ(variable_name_table_ptr[2], 0); // 2 data bytes
    ASSERT_EQ(variable_name_table_ptr[3], 0);
    ASSERT_EQ(variable_name_table_ptr[4], 0); // end of variable name table
    ASSERT_PTR_EQ(name_ptr, variable_name_table_ptr + 2);
    ASSERT_PTR_EQ(free_ptr, variable_name_table_ptr + 4 + 1);

    // Should be able to find X now
    call_find_name("X", variable_name_table_ptr, 0, variable_name_table_ptr + 2, __LINE__);

    // Add more variables
    call_find_name_fail("AB", variable_name_table_ptr, 1, variable_name_table_ptr + 4, __LINE__);
    add_variable(511);
    HEXDUMP(variable_name_table_ptr, ((char*)free_ptr - variable_name_table_ptr));
    ASSERT_EQ(err, 0);
    ASSERT_EQ(variable_name_table_ptr[4], 0x82); // length (515) high byte with high bit set
    ASSERT_EQ(variable_name_table_ptr[5], 0x03); // length low byte
    ASSERT_EQ(variable_name_table_ptr[6], 'A');
    ASSERT_EQ(variable_name_table_ptr[7], 'B' | NT_STOP);
    ASSERT_EQ(variable_name_table_ptr[8], 0); // data bytes
    ASSERT_EQ(variable_name_table_ptr[519], 0); // end of variable name table
    ASSERT_PTR_EQ(name_ptr, variable_name_table_ptr + 4 + 4);
    ASSERT_PTR_EQ(free_ptr, variable_name_table_ptr + 4 + 515 + 1);

    call_find_name_fail("Y", variable_name_table_ptr, 2, variable_name_table_ptr + 4 + 515, __LINE__);
    add_variable(6);
    HEXDUMP(variable_name_table_ptr, ((char*)free_ptr - variable_name_table_ptr));

    call_find_name("X", variable_name_table_ptr, 0, variable_name_table_ptr + 2, __LINE__);
    call_find_name("AB", variable_name_table_ptr, 1, variable_name_table_ptr + 4 + 4, __LINE__);
    call_find_name("Y", variable_name_table_ptr, 2, variable_name_table_ptr + 4 + 515 + 2, __LINE__);

    ASSERT_PTR_EQ(free_ptr, variable_name_table_ptr + 4 + 515 + 8 + 1);
}

int main(void) {
    initialize_target();
    test_initialize_name_ptr();
    test_advance_name_ptr();
    test_find_name();
    test_find_name_operators();
    test_add_variable();
    return 0;
}