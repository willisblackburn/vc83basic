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

    const char name_table_data[] = { 6, 'L', 'I', 'S', 'T' | EOT, 1, 10, 'P', 'R', 'I', 'N', 'T' | EOT, 1, 
        'T', 'O' | EOT, 1, 0x80, 5, 'R', 'U', 'N' | EOT, 1 | 0x80, 254 };
    char name_table[532];

    PRINT_TEST_NAME();

    memset(name_table, 0, sizeof name_table);
    memcpy(name_table, name_table_data, sizeof name_table_data);

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
    ASSERT_PTR_EQ(name_ptr, name_table + 6 + 10 + 2);
    ASSERT_PTR_EQ(next_name_ptr, name_table + 6 + 10 + 5);
    advance_name_ptr();
    ASSERT_EQ(err, 0);
    ASSERT_PTR_EQ(name_ptr, name_table + 6 + 10 + 5 + 2);
    ASSERT_PTR_EQ(next_name_ptr, name_table + 6 + 10 + 5 + 510);
    advance_name_ptr();
    ASSERT_NE(err, 0);
    ASSERT_PTR_EQ(name_ptr, name_table + 6 + 10 + 5 + 510);
    ASSERT_PTR_EQ(next_name_ptr, name_table + 6 + 10 + 5 + 510);
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

void test_get_name(void) {

    const char name_table[] = {
        6, 'R', 'E', 'A', 'D', 'Y',
        8, 'S', 'T', 'O', 'P', 'P', 'E', 'D',
        13, 'S', 'Y', 'N', 'T', 'A', 'X', ' ', 'E', 'R', 'R', 'O', 'R',
        7, 'U', 'N', 'U', 'S', 'E', 'D',
        0
    };

    PRINT_TEST_NAME();

    get_name(name_table, 0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(name_ptr, name_table + 1);

    get_name(name_table, 1);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(name_ptr, name_table + 6 + 1);

    get_name(name_table, 2);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(name_ptr, name_table + 6 + 8 + 1);

    get_name(name_table, 3);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(name_ptr, name_table + 6 + 8 + 13 + 1);

    get_name(name_table, 10);
    ASSERT_NE(err, 0);
    ASSERT_EQ(name_ptr, name_table + 6 + 8 + 13 + 7);
}

void test_add_variable(void) {
    const char num_init_value[] = { TYPE_NUMBER, 0, 0, 0, 0, 0 };

    PRINT_TEST_NAME();

    // Call initialize_program to set up variable_name_table_ptr.
    initialize_program();
    ASSERT_EQ(variable_name_table_ptr[0], 0);
    ASSERT_PTR_EQ(array_name_table_ptr, variable_name_table_ptr + 1);

    // add_variable is used after find_name, which sets up name_ptr.
    // The call_find_name_fail function sets decode_name_ptr.
    call_find_name_fail("X", variable_name_table_ptr, 0, variable_name_table_ptr, __LINE__);
    add_variable();
    HEXDUMP(variable_name_table_ptr, ((char*)free_ptr - variable_name_table_ptr));
    ASSERT_EQ(err, 0);
    ASSERT_EQ(variable_name_table_ptr[0], 7); // length
    ASSERT_EQ(variable_name_table_ptr[1], 'X' | EOT);
    ASSERT_EQ(variable_name_table_ptr[2], 0); // 5 data bytes ...
    ASSERT_EQ(variable_name_table_ptr[7], 0); // end of variable name table
    ASSERT_PTR_EQ(name_ptr, variable_name_table_ptr + 2);
    ASSERT_PTR_EQ(array_name_table_ptr, variable_name_table_ptr + 7 + 1);

    // Should be able to find X now
    call_find_name("X", variable_name_table_ptr, 0, variable_name_table_ptr + 2, __LINE__);

    // Add more variables
    call_find_name_fail("AB", variable_name_table_ptr, 1, variable_name_table_ptr + 7, __LINE__);
    add_variable();
    HEXDUMP(variable_name_table_ptr, ((char*)free_ptr - variable_name_table_ptr));
    ASSERT_EQ(err, 0);
    ASSERT_EQ(variable_name_table_ptr[7], 8); // length
    ASSERT_EQ(variable_name_table_ptr[8], 'A');
    ASSERT_EQ(variable_name_table_ptr[9], 'B' | EOT);
    ASSERT_EQ(variable_name_table_ptr[10], 0); // 5 data bytes ...
    ASSERT_EQ(variable_name_table_ptr[15], 0); // end of variable name table
    ASSERT_PTR_EQ(name_ptr, variable_name_table_ptr + 7 + 3);
    ASSERT_PTR_EQ(array_name_table_ptr, variable_name_table_ptr + 7 + 8 + 1);

    call_find_name_fail("Y", variable_name_table_ptr, 2, variable_name_table_ptr + 7 + 8, __LINE__);
    add_variable();
    HEXDUMP(variable_name_table_ptr, ((char*)array_name_table_ptr - variable_name_table_ptr));

    call_find_name("X", variable_name_table_ptr, 0, variable_name_table_ptr + 2, __LINE__);
    call_find_name("AB", variable_name_table_ptr, 1, variable_name_table_ptr + 7 + 3, __LINE__);
    call_find_name("Y", variable_name_table_ptr, 2, variable_name_table_ptr + 7 + 8 + 2, __LINE__);

    ASSERT_PTR_EQ(array_name_table_ptr, variable_name_table_ptr + 7 + 8 + 7 + 1);
}

int call_test_imul_16(int value1, int value2) {
    array_element_size = value1;
    return imul_16(value2);
}

void test_imul_16(void) {
    int result;
    
    PRINT_TEST_NAME();

    result = call_test_imul_16(0, 0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(result, 0);
    result = call_test_imul_16(1, 0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(result, 0);
    result = call_test_imul_16(1, 1);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(result, 1);
    result = call_test_imul_16(1, 2);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(result, 2);
    result = call_test_imul_16(2, 1);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(result, 2);
    result = call_test_imul_16(2, 2);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(result, 4);
    result = call_test_imul_16(3, 45);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(result, 135);
    result = call_test_imul_16(100, 90);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(result, 9000);
    result = call_test_imul_16(1, 32767);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(result, 32767);
    result = call_test_imul_16(2, 32767);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(result, -2); // Rolls over

    result = call_test_imul_16(1000, 1000);
    ASSERT_NE(err, 0);
    result = call_test_imul_16(3, 32767);
    ASSERT_NE(err, 0);
}

void test_dimension_array() {
    const char line_data_1[] = { 'X' | EOT, '(', '3', ')' };
    const char line_data_2[] = { 'Y' | EOT, '(', '2', '5', ',', '5', ')' };
    const char line_data_3[] = { 'A', '$' | EOT, '(', '5', ')' };
    const char expect_array_data_1[] = {
        0x80, 0x1A,     // size (26 bytes)
        'X' | EOT,      // name
        0x01,           // arity
        0x14, 0x00,     // dimension 1
        0, 0, 0, 0, 0,  // index 0
        0, 0, 0, 0, 0,  // index 1
        0, 0, 0, 0, 0,  // index 2
        0, 0, 0, 0, 0,  // index 3
        0               // next entry: end of table
    };
    const char expect_array_data_2[] = {
        0x83, 0x14,     // size (788 bytes)
        'Y' | EOT,      // name
        0x02,           // arity
        0x1E, 0x00,     // dimension 1
        0x0C, 0x03,     // dimension 2
        // ... 780 bytes of data ...
    };
    const char expect_array_data_3[] = {
        0x80, 0x13,     // size (19 bytes)
        'A', '$' | EOT, // name
        0x01,           // arity
        0x0C, 0x00,     // dimension 1
        0, 0,           // index 0
        0, 0,           // index 1
        0, 0,           // index 2
        0, 0,           // index 3
        0, 0,           // index 4
        0, 0,           // index 5
        0               // next entry: end of table
    };
    char index;
 
    PRINT_TEST_NAME();

    // Test 1-dimensional array

    // Call initialize_program to set up variable_name_table_ptr.
    initialize_program();
    ASSERT_EQ(array_name_table_ptr[0], 0);
    ASSERT_PTR_EQ(free_ptr, array_name_table_ptr + 1);

    // Single-dimension array

    // Look up X as an array
    set_line(0, line_data_1, sizeof line_data_1);
    decode_name();
    ASSERT_EQ(decode_name_type, TYPE_NUMBER);
    ASSERT_EQ(decode_name_arity, -1);
    index = find_name(array_name_table_ptr);
    ASSERT_NE(err, 0);
    ASSERT_EQ(index, 0);

    // Parse dimension values (returns input minus number of args read; negate to get arity)
    decode_name_arity = -evaluate_argument_list(0);
    ASSERT_EQ(decode_name_arity, 1);

    // Make sure argument is on the stack
    ASSERT_EQ(stack_pos, PRIMARY_STACK_SIZE - 6);

    // Add as new array
    dimension_array();
    ASSERT_EQ(err, 0);

    HEXDUMP(array_name_table_ptr, 64);

    // We now expect to find in the array name table:
    // Name table entry length (2 bytes, high-low, MSB set): $80, $1A
    // Name: 'X' | EOT ($D8)
    // Arity: $01
    // Dimension values (2 bytes, low-high): $14, $00
    // Data: 4 floats (indexes 0-3) * 5 bytes = 20 bytes
    // Total 26 bytes

    ASSERT_PTR_EQ(free_ptr, array_name_table_ptr + 26 + 1);
    ASSERT_MEMORY_EQ(array_name_table_ptr, expect_array_data_1, sizeof expect_array_data_1);

    // Test 2-dimensional array

    // Look up Y as an array
    set_line(0, line_data_2, sizeof line_data_2);
    decode_name();
    ASSERT_EQ(decode_name_type, TYPE_NUMBER);
    ASSERT_EQ(decode_name_arity, -1);
    index = find_name(array_name_table_ptr);
    ASSERT_NE(err, 0);
    ASSERT_EQ(index, 1);

    // Parse dimension values
    decode_name_arity = -evaluate_argument_list(0);
    ASSERT_EQ(decode_name_arity, 2);

    // Make sure argument is on the stack
    ASSERT_EQ(stack_pos, PRIMARY_STACK_SIZE - 12);

    // Add as new array
    dimension_array();
    ASSERT_EQ(err, 0);

    HEXDUMP(array_name_table_ptr, 64);

    // All the stuff that was there before should still be there, plus:
    // Second name table entry length: $83 $14
    // Name: 'Y' | EOT
    // Arity: $02
    // Dimension values (last dimension comes first): $1E, $00, $0C, $03
    // Data: 156 floats * 5 bytes = 780 bytes
    // Total: 788 bytes

    ASSERT_PTR_EQ(free_ptr, array_name_table_ptr + 26 + 788 + 1);
    ASSERT_MEMORY_EQ(array_name_table_ptr + 26, expect_array_data_2, sizeof expect_array_data_2);

    // Test string array

    // Look up A$ as an array
    set_line(0, line_data_3, sizeof line_data_3);
    decode_name();
    ASSERT_EQ(decode_name_type, TYPE_STRING);
    ASSERT_EQ(decode_name_arity, -1);
    index = find_name(array_name_table_ptr);
    ASSERT_NE(err, 0);
    ASSERT_EQ(index, 2);

    // Parse dimension values
    decode_name_arity = -evaluate_argument_list(0);
    ASSERT_EQ(decode_name_arity, 1);

    // Make sure argument is on the stack
    ASSERT_EQ(stack_pos, PRIMARY_STACK_SIZE - 6);

    // Add as new array
    dimension_array();
    ASSERT_EQ(err, 0);

    HEXDUMP(array_name_table_ptr, 64);

    // Verify array name table again

    ASSERT_PTR_EQ(free_ptr, array_name_table_ptr + 26 + 788 + 19 + 1);
    ASSERT_MEMORY_EQ(array_name_table_ptr + 26 + 788, expect_array_data_3, sizeof expect_array_data_3);
}

void call_find_array_element(const char* line_data, size_t line_data_length, char expect_index,
    const char* expect_name_ptr, int line) {
    char index;

    fprintf(stderr, "  %s:%d: find_array_element()\n", __FILE__, line);

    set_line(0, line_data, line_data_length);
    decode_name();
    ASSERT_EQ(decode_name_type, TYPE_NUMBER);
    ASSERT_EQ(decode_name_arity, -1);
    index = find_name(array_name_table_ptr);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(index, expect_index);

    decode_name_arity = -evaluate_argument_list(0);
    find_array_element();
    ASSERT_EQ(err, 0);
    ASSERT_PTR_EQ(name_ptr, expect_name_ptr);
}

void test_find_array_element() {
    const char line_data_1[] = { 'X' | EOT, '(', '3', ')' };
    const char line_data_2[] = { 'Y' | EOT, '(', '2', '5', ',', '5', ')' };
    const char line_data_x_0[] = { 'X' | EOT, '(', '0', ')' };
    const char line_data_x_1[] = { 'X' | EOT, '(', '1', ')' };
    const char line_data_x_3[] = { 'X' | EOT, '(', '3', ')' };
    const char line_data_x_4[] = { 'X' | EOT, '(', '3', ')' };
    const char line_data_y_0_0[] = { 'Y' | EOT, '(', '0', ',', '0', ')' };
    const char line_data_y_1_1[] = { 'Y' | EOT, '(', '1', ',', '1', ')' };
    const char line_data_y_26_1[] = { 'Y' | EOT, '(', '2', '6', ',', '1', ')' };
    char index;

    PRINT_TEST_NAME();

    // Call initialize_program to set up variable_name_table_ptr.
    initialize_program();

    // Create a one-dimensional array and a two-dimensional array.
    // The dimension_array API has already been tested.

    // X
    set_line(0, line_data_1, sizeof line_data_1);
    decode_name();
    index = find_name(array_name_table_ptr);
    ASSERT_NE(err, 0);
    ASSERT_EQ(index, 0);
    decode_name_arity = -evaluate_argument_list(0);
    dimension_array();
    ASSERT_EQ(err, 0);

    // Offset 0 -> 6 to skip length (2), name (1), arity (1), dimension value (2)
    // Offset 1 -> 6 + 5 (first value)
    // etc.
    call_find_array_element(line_data_x_0, sizeof line_data_x_0, 0, array_name_table_ptr + 6, __LINE__);
    call_find_array_element(line_data_x_1, sizeof line_data_x_1, 0, array_name_table_ptr + 6 + 5, __LINE__);
    call_find_array_element(line_data_x_3, sizeof line_data_x_3, 0, array_name_table_ptr + 6 + 15, __LINE__);

    // Y
    set_line(0, line_data_2, sizeof line_data_2);
    decode_name();
    index = find_name(array_name_table_ptr);
    ASSERT_NE(err, 0);
    ASSERT_EQ(index, 1);
    decode_name_arity = -evaluate_argument_list(0);
    dimension_array();
    ASSERT_EQ(err, 0);

    // Offset 0, 0 -> 26 (offset of Y) + 8
    // Offset 1, 1 -> 26 + 8 + 5 (first value on row 1) + 30 (all 6 values of row 0)
    call_find_array_element(line_data_y_0_0, sizeof line_data_y_0_0, 1, array_name_table_ptr + 26 + 8, __LINE__);
    call_find_array_element(line_data_y_1_1, sizeof line_data_y_1_1, 1, array_name_table_ptr + 26 + 8 + 5 + 30,
        __LINE__);

    // Make sure bounds checks work.
    set_line(0, line_data_y_26_1, sizeof line_data_y_26_1);
    decode_name();
    find_name(array_name_table_ptr);
    decode_name_arity = -evaluate_argument_list(0);
    find_array_element();
    ASSERT_NE(err, 0);
}


int main(void) {
    initialize_target();
    test_initialize_name_ptr();
    test_advance_name_ptr();
    test_find_name();
    test_find_name_operators();
    test_get_name();
    test_add_variable();
    test_imul_16();
    test_dimension_array();
    test_find_array_element();
    return 0;
}