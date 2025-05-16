#include "test.h"

void test_initialize_name_ptr(void) {

    PRINT_TEST_NAME();

    name_ptr = NULL;
    next_name_ptr = NULL;

    initialize_name_ptr((void*)0xA000);
    ASSERT_PTR_EQ(name_ptr, NULL);
    ASSERT_PTR_EQ(next_name_ptr, (void*)0xA000);
}

void test_advance_name_ptr(void) {

    const char name_table[] = { 6, 'L', 'I', 'S', 'T' | EOT, 1, 10, 'P', 'R', 'I', 'N', 'T' | EOT, 1, 
        'T', 'O' | EOT, 1, 4, 'R', 'U', 'N' | EOT, 0  };

    PRINT_TEST_NAME();

    // Pre-requisite
    next_name_ptr = name_table;

    advance_name_ptr();
    ASSERT_EQ(err, 0);
    ASSERT_PTR_EQ(name_ptr, name_table + 1);
    ASSERT_PTR_EQ(next_name_ptr, name_table + 6);
    advance_name_ptr();
    ASSERT_EQ(err, 0);
    ASSERT_PTR_EQ(name_ptr, name_table + 6 + 1);
    ASSERT_PTR_EQ(next_name_ptr, name_table + 6 + 10);
    advance_name_ptr();
    ASSERT_EQ(err, 0);
    ASSERT_PTR_EQ(name_ptr, name_table + 6 + 10 + 1);
    ASSERT_PTR_EQ(next_name_ptr, name_table + 6 + 10 + 4);
    advance_name_ptr();
    ASSERT_NE(err, 0);
}

void call_find_name(const char* name, const char* name_table_ptr, char expect_index,
    const char* expect_name_ptr, int line) {        
    char index;
    fprintf(stderr, "  %s:%d: find_name(\"%s\")\n", __FILE__, line, name);
    parse_and_decode_name(name);
    HEXDUMP(name_table_ptr, 32);
    index = find_name(name_table_ptr);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(index, expect_index);
    ASSERT_PTR_EQ(name_ptr, expect_name_ptr);
}

void call_find_name_fail(const char* name, const char* name_table_ptr, char expect_index,
    const char* expect_name_ptr, int line) {
    char index;
    fprintf(stderr, "  %s:%d: find_name(\"%s\")\n", __FILE__, line, name);
    parse_and_decode_name(name);
    HEXDUMP(name_table_ptr, 32);
    index = find_name(name_table_ptr);
    ASSERT_NE(err, 0);
    ASSERT_EQ(index, expect_index);
    // On fail name_ptr should always point to 0 at the end of the name table.
    ASSERT_PTR_EQ(name_ptr, expect_name_ptr);
}

void test_find_name(void) {

    const char name_table_1[] = { 6, 'P', 'R', 'I', 'N', 'T' | EOT, 0 };
    const char name_table_2[] = { 6, 'P', 'R', 'I', 'N', 'T' | EOT, 1, 'X' | EOT, 0 };
    const char name_table_3[] = { 2, 'X' | EOT, 6, 'P', 'R', 'I', 'N', 'T' | EOT, 0 };
    const char name_table_4[] = { 5, 'L', 'I', 'S', 'T' | EOT, 10, 'P', 'R', 'I', 'N', 'T' | EOT, 1, 
        'T', 'O' | EOT, 1, 0 };
    const char name_table_5[] = { 6, 'L', 'I', 'S', 'T' | EOT, 1, 10, 'P', 'R', 'I', 'N', 'T' | EOT, 1, 
        'T', 'O' | EOT, 1, 0 };
    const char name_table_6[] = { 5, 'L', 'I', 'S', 'T' | EOT, 0 };
    const char name_table_7[] = { 8, 'P', 'R', 'I', 'N', 'T', 'E', 'R' | EOT, 0 };
    const char name_table_8[] = { 5, 'L', 'I', 'S', 'T' | EOT, 8, 'P', 'R', 'I', 'N', 'T', 'E', 'R' | EOT, 0 };
    const char name_table_9[] = { 5, 'P', 'R', 'I', 'N' | EOT, 0 };
    const char name_table_10[] = { 5, 'L', 'I', 'S', 'T' | EOT, 5, 'P', 'R', 'I', 'N' | EOT, 0 };

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

    const char name_table_1[] = { 3, '>', '=' | EOT, 0 };
    const char name_table_2[] = { 2, '>' | EOT, 3, '>', '=' | EOT, 0 };
    const char name_table_3[] = { 2, '=' | EOT, 3, '>', '=' | EOT, 2, '>' | EOT, 0 };

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
    // The call_find_name_fail function sets decode_name_ptr.
    call_find_name_fail("X", variable_name_table_ptr, 0, variable_name_table_ptr, __LINE__);
    add_variable();
    HEXDUMP(variable_name_table_ptr, ((char*)free_ptr - variable_name_table_ptr));
    ASSERT_EQ(err, 0);
    ASSERT_EQ(variable_name_table_ptr[0], 4); // length
    ASSERT_EQ(variable_name_table_ptr[1], 'X' | EOT);
    ASSERT_EQ(variable_name_table_ptr[2], 0); // 2 data bytes ...
    ASSERT_EQ(variable_name_table_ptr[4], 0); // end of variable name table
    ASSERT_PTR_EQ(name_ptr, variable_name_table_ptr + 2);
    ASSERT_PTR_EQ(free_ptr, variable_name_table_ptr + 4 + 1);

    // Should be able to find X now
    call_find_name("X", variable_name_table_ptr, 0, variable_name_table_ptr + 2, __LINE__);

    // Add more variables
    call_find_name_fail("AB", variable_name_table_ptr, 1, variable_name_table_ptr + 4, __LINE__);
    add_variable();
    HEXDUMP(variable_name_table_ptr, ((char*)free_ptr - variable_name_table_ptr));
    ASSERT_EQ(err, 0);
    ASSERT_EQ(variable_name_table_ptr[4], 5); // length
    ASSERT_EQ(variable_name_table_ptr[5], 'A');
    ASSERT_EQ(variable_name_table_ptr[6], 'B' | EOT);
    ASSERT_EQ(variable_name_table_ptr[7], 0); // 2 data bytes ...
    ASSERT_EQ(variable_name_table_ptr[9], 0); // end of variable name table
    ASSERT_PTR_EQ(name_ptr, variable_name_table_ptr + 4 + 3);
    ASSERT_PTR_EQ(free_ptr, variable_name_table_ptr + 4 + 5 + 1);

    call_find_name_fail("Y", variable_name_table_ptr, 2, variable_name_table_ptr + 4 + 5, __LINE__);
    add_variable();
    HEXDUMP(variable_name_table_ptr, ((char*)free_ptr - variable_name_table_ptr));

    call_find_name("X", variable_name_table_ptr, 0, variable_name_table_ptr + 2, __LINE__);
    call_find_name("AB", variable_name_table_ptr, 1, variable_name_table_ptr + 4 + 3, __LINE__);
    call_find_name("Y", variable_name_table_ptr, 2, variable_name_table_ptr + 4 + 5 + 2, __LINE__);

    ASSERT_PTR_EQ(free_ptr, variable_name_table_ptr + 4 + 5 + 4 + 1);
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