#include "test.h"

static void test_initalize_program(void) {
    PRINT_TEST_NAME();

    initialize_program();

    ASSERT_EQ(next_line_ptr, program_ptr);
    ASSERT_EQ(next_line_ptr->next_line_offset, sizeof (Line) + 2); // +1 for next statement offset +1 for END token
    ASSERT_EQ(next_line_ptr->number, -1);
    ASSERT_EQ((char*)variable_name_table_ptr, (char*)program_ptr + sizeof (Line) + 2);
    ASSERT_EQ(*variable_name_table_ptr, 0);
    ASSERT_EQ((void*)value_table_ptr, (void*)(variable_name_table_ptr + 1)); // Variable name table is empty with terminating 0
    ASSERT_EQ((void*)free_ptr, (void*)value_table_ptr);
    ASSERT_LT((void*)free_ptr, (void*)himem_ptr);
}

static void test_reset_next_line_ptr(void) {
    PRINT_TEST_NAME();

    initialize_program();

    // After altering next_line_ptr, reset_next_line_ptr should set it back.
    next_line_ptr = NULL;
    reset_next_line_ptr();

    ASSERT_EQ(next_line_ptr, program_ptr);
}

static void test_advance_next_line_ptr(void) {
    PRINT_TEST_NAME();

    // Calling advance_next_line_ptr on the empty program should advance next_line_ptr to variable_name_table_ptr.
    initialize_program();
    advance_next_line_ptr();
    ASSERT_EQ((void*)next_line_ptr, (void*)variable_name_table_ptr);

    // If we put in a fake lines with various lengths then line_ptr should advance by the size of each.
    // Note that we're charging into unallocated memory here, but that's okay since we own memory space
    // after the BSS.
    initialize_program();
    next_line_ptr->next_line_offset = 10;
    advance_next_line_ptr();
    ASSERT_EQ((char*)next_line_ptr, (char*)program_ptr + 10);
    next_line_ptr->next_line_offset = 250;
    advance_next_line_ptr();
    ASSERT_EQ((char*)next_line_ptr, (char*)program_ptr + 10 + 250);
}

static void test_find_line(void) {
    int err;

    PRINT_TEST_NAME();

    initialize_program();

    ASSERT_EQ(next_line_ptr, program_ptr);

    // Add three lines: 10, 256, and 10000.
    // It doesn't matter what the actual line data is since we're not going to execute it.
    next_line_ptr->next_line_offset = 5;
    next_line_ptr->number = 10;

    // Since we know advance_next_line_ptr works, we can use it to move to the next space in memory.
    advance_next_line_ptr();
    next_line_ptr->next_line_offset = 250;
    next_line_ptr->number = 256;
    advance_next_line_ptr();
    next_line_ptr->next_line_offset = 10;
    next_line_ptr->number = 10000;
    advance_next_line_ptr();
    next_line_ptr->next_line_offset = 0;
    next_line_ptr->number = -1;
    // Patch up the program end.
    advance_next_line_ptr();
    variable_name_table_ptr = (char*)next_line_ptr;
    value_table_ptr = line_ptr;

    // Test if we can find each line separately.
    err = find_line_ax(10);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(next_line_ptr->number, 10);
    err = find_line_ax(256);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(next_line_ptr->number, 256);
    err = find_line_ax(10000);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(next_line_ptr->number, 10000);

    // Test not finding a line at all.
    // In this case line_ptr should point to where the line would have been, i.e., line 256.
    err = find_line_ax(15);
    ASSERT_NE(err, 0);
    ASSERT_EQ(next_line_ptr->number, 256);

    // Test finding a line that occurs earlier in the program.
    err = find_line_ax(10000);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(next_line_ptr->number, 10000);
    err = find_line_ax(10);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(next_line_ptr->number, 10);
}

static void test_insert_or_update_line(void) {
    int err;
    const char line_5_data[] = { 'E', 'N', 'D' };
    const char line_10_data[] = { 'P', 'R', 'I', 'N', 'T', ' ', '1' };
    const char line_200_data[] = { 'P', 'R', 'I', 'N', 'T', ' ', '3', '.', '1', '4', '1', '5', '9' };

    PRINT_TEST_NAME();

    initialize_program();

    set_line(10, line_10_data, sizeof line_10_data);
    err = insert_or_update_line();
    ASSERT_EQ(err, 0);
    reset_next_line_ptr();
    ASSERT_EQ(next_line_ptr->next_line_offset, sizeof (Line) + sizeof line_10_data);  
    ASSERT_EQ(next_line_ptr->number, 10);    
    ASSERT_MEMORY_EQ(next_line_ptr->data, line_10_data, sizeof line_10_data);  
    
    advance_next_line_ptr();
    ASSERT_EQ(next_line_ptr->next_line_offset, sizeof (Line) + 2);    
    ASSERT_EQ(next_line_ptr->number, -1);    

    set_line(200, line_200_data, sizeof line_200_data);
    err = insert_or_update_line();
    ASSERT_EQ(err, 0);
    reset_next_line_ptr();
    ASSERT_EQ(next_line_ptr->next_line_offset, sizeof (Line) + sizeof line_10_data);    
    ASSERT_EQ(next_line_ptr->number, 10);    
    advance_next_line_ptr();
    ASSERT_EQ(next_line_ptr->next_line_offset, sizeof (Line) + sizeof line_200_data);    
    ASSERT_EQ(next_line_ptr->number, 200);    
    advance_next_line_ptr();
    ASSERT_EQ(next_line_ptr->next_line_offset, sizeof (Line) + 2);    
    ASSERT_EQ(next_line_ptr->number, -1);    

    // Test inserting a line before the other two.
    set_line(5, line_5_data, sizeof line_5_data);
    err = insert_or_update_line();
    ASSERT_EQ(err, 0);
    reset_next_line_ptr();
    ASSERT_EQ(next_line_ptr->next_line_offset, sizeof (Line) + sizeof line_5_data);    
    ASSERT_EQ(next_line_ptr->number, 5);    
    advance_next_line_ptr();
    ASSERT_EQ(next_line_ptr->next_line_offset, sizeof (Line) + sizeof line_10_data);    
    ASSERT_EQ(next_line_ptr->number, 10);    
    advance_next_line_ptr();
    ASSERT_EQ(next_line_ptr->next_line_offset, sizeof (Line) + sizeof line_200_data);    
    ASSERT_EQ(next_line_ptr->number, 200);    
    advance_next_line_ptr();
    ASSERT_EQ(next_line_ptr->next_line_offset, sizeof (Line) + 2);    
    ASSERT_EQ(next_line_ptr->number, -1);    

    // Test deleting a line.
    set_line(200, line_200_data, 0);
    err = insert_or_update_line();
    ASSERT_EQ(err, 0);
    reset_next_line_ptr();
    ASSERT_EQ(next_line_ptr->next_line_offset, sizeof (Line) + sizeof line_5_data);    
    ASSERT_EQ(next_line_ptr->number, 5);    
    advance_next_line_ptr();
    ASSERT_EQ(next_line_ptr->next_line_offset, sizeof (Line) + sizeof line_10_data);    
    ASSERT_EQ(next_line_ptr->number, 10);    
    advance_next_line_ptr();
    ASSERT_EQ(next_line_ptr->number, -1);    
    ASSERT_EQ(next_line_ptr->next_line_offset, sizeof (Line) + 2);    
}

static void test_check_himem(void) {
    char err;

    PRINT_TEST_NAME();

    free_ptr = (void*)0x1000;
    himem_ptr = (void*)0x2000;

    err = check_himem(0x0F00);
    ASSERT_EQ(err, 0);

    err = check_himem(0x1F00);
    ASSERT_NE(err, 0);

    himem_ptr = (void*)0xFF00;

    err = check_himem(0xEF00);
    ASSERT_EQ(err, 0);

    err = check_himem(0xFF00);
    ASSERT_NE(err, 0);
}

static void test_calculate_bytes_to_move(void) {

    PRINT_TEST_NAME();

    // The function just calculates the difference between src_ptr and free_ptr.

    src_ptr = (void*)0x0400;
    free_ptr = (void*)0x2000;

    calculate_bytes_to_move();
    ASSERT_EQ(size, 0x1C00);
}

static void test_grow(void) {

    char err;

    PRINT_TEST_NAME();

    initialize_program();

    // Add 3 bytes to the program space by adding to line_ptr.
    // First make sure line_ptr points to the beginning of the program.
    ASSERT_EQ(next_line_ptr, program_ptr);

    // Add 3 bytes.
    err = grow(&next_line_ptr, 3);
    ASSERT_EQ(err, 0);

    // Set line_ptr back to program_ptr. There should now be 3 bytes where we can put stuff.
    next_line_ptr = program_ptr;
    next_line_ptr->next_line_offset = 3;
    next_line_ptr->number = 20;

    // Now move it up 3 again.
    err = grow(&next_line_ptr, 3);
    ASSERT_EQ(err, 0);
    next_line_ptr = program_ptr;
    next_line_ptr->next_line_offset = 3;
    next_line_ptr->number = 10;

    // Other pointers should be at their correct positions.

    ASSERT_EQ(next_line_ptr, program_ptr);
    ASSERT_EQ(variable_name_table_ptr, (char*)next_line_ptr + 11); // 11 is 2 lines of 3 + 5 bytes for END
    ASSERT_EQ(*variable_name_table_ptr, 0);
    ASSERT_EQ(value_table_ptr, (void*)(variable_name_table_ptr + 1));
    ASSERT_EQ(free_ptr, value_table_ptr);

    // Verify the program contents.
    ASSERT_EQ(next_line_ptr->next_line_offset, 3);
    ASSERT_EQ(next_line_ptr->number, 10);
    next_line_ptr = (Line*)((char*)next_line_ptr + next_line_ptr->next_line_offset);
    ASSERT_EQ(next_line_ptr->next_line_offset, 3);
    ASSERT_EQ(next_line_ptr->number, 20);
    next_line_ptr = (Line*)((char*)next_line_ptr + next_line_ptr->next_line_offset);
    ASSERT_EQ(next_line_ptr->next_line_offset, 5);
    ASSERT_EQ(next_line_ptr->number, -1);

    // Now grow free_ptr by 1K.
    // Nothing should change except free_ptr.

    next_line_ptr = program_ptr;
    err = grow(&free_ptr, 0x400);
    ASSERT_EQ(err, 0);

    ASSERT_EQ(next_line_ptr, program_ptr);
    ASSERT_EQ(variable_name_table_ptr, (char*)next_line_ptr + 11);
    ASSERT_EQ(*variable_name_table_ptr, 0);
    ASSERT_EQ(value_table_ptr, (void*)(variable_name_table_ptr + 1));
    ASSERT_EQ((char*)free_ptr, (char*)value_table_ptr + 0x400);
}

static void test_shrink(void) {
    char err;

    const char variable_name_data[] = { 'A' | NT_END, 'B' | NT_END, 'X', 'Y' | NT_END, 0 };
    const char value_data[] = { 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17 };

    // To test shrink, we first grow some sections, write some data to them, then make sure that data is
    // preserved when we shrink. We know that grow works because it's been separately tested.

    PRINT_TEST_NAME();

    initialize_program();

    // Create some program space.
    err = grow(&variable_name_table_ptr, 0x400);
    ASSERT_EQ(err, 0);

    // Expand the variable name table by moving the value table pointer.
    // The variable name table already contains 1 byte, so subtract 1 from the size of the data we want to write.
    err = grow(&value_table_ptr, sizeof variable_name_data - 1);
    ASSERT_EQ(err, 0);
    // Fill in some variable names.
    memcpy(variable_name_table_ptr, variable_name_data, sizeof variable_name_data);

    // Add some space for some variable values.
    err = grow(&free_ptr, sizeof value_data + 0x1000);
    ASSERT_EQ(err, 0);
    memcpy(value_table_ptr, value_data, sizeof value_data);

    // Make sure all the pointers are where they should be.

    ASSERT_EQ(next_line_ptr, program_ptr);
    ASSERT_EQ(variable_name_table_ptr, (char*)next_line_ptr + 5 + 0x400);
    ASSERT_EQ(value_table_ptr, (void*)(variable_name_table_ptr + sizeof variable_name_data));
    ASSERT_EQ((char*)free_ptr, (char*)value_table_ptr + sizeof value_data + 0x1000);

    // Now shrink each section, each time checking that no data is corrupted.

    err = shrink(&variable_name_table_ptr, 0x10);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(variable_name_table_ptr, (char*)next_line_ptr + 5 + 0x400 - 0x10);
    ASSERT_MEMORY_EQ(variable_name_table_ptr, variable_name_data, sizeof variable_name_data);
    ASSERT_EQ(value_table_ptr, (void*)(variable_name_table_ptr + sizeof variable_name_data));
    ASSERT_MEMORY_EQ(value_table_ptr, value_data, sizeof value_data);
    ASSERT_EQ((char*)free_ptr, (char*)value_table_ptr + sizeof value_data + 0x1000);

    err = shrink(&value_table_ptr, 4);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(variable_name_table_ptr, (char*)next_line_ptr + 5 + 0x400 - 0x10);
    ASSERT_MEMORY_EQ(variable_name_table_ptr, variable_name_data, sizeof variable_name_data - 4);
    ASSERT_EQ(value_table_ptr, (void*)(variable_name_table_ptr + sizeof variable_name_data - 4));
    ASSERT_MEMORY_EQ(value_table_ptr, value_data, sizeof value_data);
    ASSERT_EQ((char*)free_ptr, (char*)value_table_ptr + sizeof value_data + 0x1000);

    err = shrink(&free_ptr, 0x200);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(variable_name_table_ptr, (char*)next_line_ptr + 5 + 0x400 - 0x10);
    ASSERT_MEMORY_EQ(variable_name_table_ptr, variable_name_data, sizeof variable_name_data - 4);
    ASSERT_EQ(value_table_ptr, (void*)(variable_name_table_ptr + sizeof variable_name_data - 4));
    ASSERT_MEMORY_EQ(value_table_ptr, value_data, sizeof value_data - 4);
    ASSERT_EQ((char*)free_ptr, (char*)value_table_ptr + sizeof value_data + 0xE00);
}

static void test_mul_value_size(void) {
    int result;

    PRINT_TEST_NAME();

    result = mul_value_size(0);
    ASSERT_EQ(result, 0);
    result = mul_value_size(1);
    ASSERT_EQ(result, VALUE_SIZE);
    result = mul_value_size(30);
    ASSERT_EQ(result, VALUE_SIZE * 30);
    result = mul_value_size(1000);
    ASSERT_EQ(result, VALUE_SIZE * 1000);
}

static void test_set_variable_value_ptr(void) {
    PRINT_TEST_NAME();

    initialize_program();

    set_variable_value_ptr(0);
    ASSERT_EQ(variable_value_ptr, (void*)((int*)value_table_ptr));
    set_variable_value_ptr(1);
    ASSERT_EQ(variable_value_ptr, (void*)((char*)value_table_ptr + VALUE_SIZE));
    set_variable_value_ptr(127);
    ASSERT_EQ(variable_value_ptr, (void*)((char*)value_table_ptr + VALUE_SIZE * 127));
}

int main(void) {
    initialize_target();
    test_initalize_program();
    test_reset_next_line_ptr();
    test_advance_next_line_ptr();
    test_find_line();
    test_insert_or_update_line();
    test_check_himem();
    test_calculate_bytes_to_move();
    test_grow();
    test_shrink();
    test_mul_value_size();
    test_set_variable_value_ptr();
    return 0;
}