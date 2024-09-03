#include "test.h"

void test_initalize_program(void) {
    PRINT_TEST_NAME();

    initialize_program();

    ASSERT_EQ(line_ptr, program_ptr);
    ASSERT_EQ(line_ptr->next_line_offset, sizeof (Line));
    ASSERT_EQ(line_ptr->number, -1);
    ASSERT_EQ((void*)variable_name_table_ptr, (void*)(program_ptr + 1)); // sizeof *program_ptr == size of the line header
    ASSERT_EQ(*variable_name_table_ptr, 0);
    ASSERT_EQ((void*)free_ptr, (void*)(variable_name_table_ptr + 1)); // Variable name table is empty with terminating 0
    ASSERT_LT((void*)free_ptr, (void*)himem_ptr);
}

void test_reset_line_ptr(void) {
    PRINT_TEST_NAME();

    initialize_program();

    // After altering line_ptr, reset_line_ptr should set it back.
    line_ptr = NULL;
    reset_line_ptr();

    ASSERT_EQ(line_ptr, program_ptr);
}

void test_advance_line_ptr(void) {
    PRINT_TEST_NAME();

    // Calling advance_line_ptr on the empty program should advance line_ptr to variable_name_table_ptr.
    initialize_program();
    advance_line_ptr();
    ASSERT_EQ((void*)line_ptr, (void*)variable_name_table_ptr);

    // If we put in a fake lines with various lengths then line_ptr should advance by the size of each.
    // Note that we're charging into unallocated memory here, but that's okay since we own memory space
    // after the BSS.
    initialize_program();
    line_ptr->next_line_offset = 10;
    advance_line_ptr();
    ASSERT_EQ((char*)line_ptr, (char*)program_ptr + 10);
    line_ptr->next_line_offset = 250;
    advance_line_ptr();
    ASSERT_EQ((char*)line_ptr, (char*)program_ptr + 10 + 250);
}

void test_grow(void) {

    PRINT_TEST_NAME();

    initialize_program();

    // Add 3 bytes to the program space by adding to line_ptr.
    // First make sure line_ptr points to the beginning of the program.
    ASSERT_EQ(line_ptr, program_ptr);

    // Add 3 bytes.
    grow(&line_ptr, 3);
    ASSERT_EQ(err, 0);

    // Set line_ptr back to program_ptr. There should now be 3 bytes where we can put stuff.
    line_ptr = program_ptr;
    line_ptr->next_line_offset = 3;
    line_ptr->number = 20;

    // Now move it up 3 again.
    grow(&line_ptr, 3);
    ASSERT_EQ(err, 0);
    line_ptr = program_ptr;
    line_ptr->next_line_offset = 3;
    line_ptr->number = 10;

    // Other pointers should be at their correct positions.

    ASSERT_PTR_EQ(line_ptr, program_ptr);
    ASSERT_PTR_EQ(variable_name_table_ptr, (char*)line_ptr + 9);
    ASSERT_EQ(*variable_name_table_ptr, 0);
    ASSERT_PTR_EQ(free_ptr, variable_name_table_ptr + 1);

    // Verify the program contents.
    ASSERT_EQ(line_ptr->next_line_offset, 3);
    ASSERT_EQ(line_ptr->number, 10);
    line_ptr = (Line*)((char*)line_ptr + line_ptr->next_line_offset);
    ASSERT_EQ(line_ptr->next_line_offset, 3);
    ASSERT_EQ(line_ptr->number, 20);
    line_ptr = (Line*)((char*)line_ptr + line_ptr->next_line_offset);
    ASSERT_EQ(line_ptr->next_line_offset, 3);
    ASSERT_EQ(line_ptr->number, -1);

    // Now grow free_ptr by 1K.
    // Nothing should change except free_ptr.

    line_ptr = program_ptr;
    grow(&free_ptr, 0x400);
    ASSERT_EQ(err, 0);

    ASSERT_PTR_EQ(line_ptr, program_ptr);
    ASSERT_PTR_EQ(variable_name_table_ptr, (char*)line_ptr + 9);
    ASSERT_EQ(*variable_name_table_ptr, 0);
    ASSERT_PTR_EQ(free_ptr, variable_name_table_ptr + 1 + 0x400);
}

void test_shrink(void) {

    const char variable_name_table_data[] = { 
        4, 'A' | NT_STOP, 0x10, 0x11, 
        4, 'B' | NT_STOP, 0x12, 0x13,
        8, 'X', 'Y' | NT_STOP, 0x14, 0x15, 0x16, 0x17, 0x18,
        0 };

    // To test shrink, we first grow some sections, write some data to them, then make sure that data is
    // preserved when we shrink. We know that grow works because it's been separately tested.

    PRINT_TEST_NAME();

    initialize_program();

    // Create some program space.
    grow(&variable_name_table_ptr, 0x400);
    ASSERT_EQ(err, 0);

    // Expand the variable name table.
    // The variable name table already contains 1 byte, so subtract 1 from the size of the data we want to write.
    grow(&free_ptr, sizeof variable_name_table_data - 1);
    ASSERT_EQ(err, 0);
    // Fill in some variable data.
    memcpy(variable_name_table_ptr, variable_name_table_data, sizeof variable_name_table_data);

    // Make sure all the pointers are where they should be.

    ASSERT_PTR_EQ(line_ptr, program_ptr);
    ASSERT_PTR_EQ(variable_name_table_ptr, (char*)line_ptr + 3 + 0x400);
    ASSERT_PTR_EQ(free_ptr, (char*)variable_name_table_ptr + sizeof variable_name_table_data);

    // Now shrink each section, each time checking that no data is corrupted.

    shrink(&variable_name_table_ptr, 0x10);
    ASSERT_EQ(err, 0);
    ASSERT_PTR_EQ(variable_name_table_ptr, (char*)line_ptr + 3 + 0x400 - 0x10);
    ASSERT_MEMORY_EQ(variable_name_table_ptr, variable_name_table_data, sizeof variable_name_table_data);
    ASSERT_PTR_EQ(free_ptr, (char*)variable_name_table_ptr + sizeof variable_name_table_data);

    shrink(&free_ptr, 4);
    ASSERT_EQ(err, 0);
    ASSERT_PTR_EQ(variable_name_table_ptr, (char*)line_ptr + 3 + 0x400 - 0x10);
    ASSERT_MEMORY_EQ(variable_name_table_ptr, variable_name_table_data, sizeof variable_name_table_data - 4);
    ASSERT_PTR_EQ(free_ptr, (char*)variable_name_table_ptr + sizeof variable_name_table_data - 4);
}

void test_find_line(void) {

    PRINT_TEST_NAME();

    initialize_program();

    ASSERT_EQ(line_ptr, program_ptr);

    // Add three lines: 10, 256, and 10000.
    // It doesn't matter what the actual line data is since we're not going to execute it.
    line_ptr->next_line_offset = 5;
    line_ptr->number = 10;

    // Since we know advance_line_ptr works, we can use it to move to the next space in memory.
    advance_line_ptr();
    line_ptr->next_line_offset = 250;
    line_ptr->number = 256;
    advance_line_ptr();
    line_ptr->next_line_offset = 10;
    line_ptr->number = 10000;
    advance_line_ptr();
    line_ptr->next_line_offset = 0;
    line_ptr->number = -1;
    // Patch up the program end.
    advance_line_ptr();
    variable_name_table_ptr = (char*)line_ptr;
    free_ptr = variable_name_table_ptr + 1;

    // Test if we can find each line separately.
    find_line(10);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(line_ptr->number, 10);
    find_line(256);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(line_ptr->number, 256);
    find_line(10000);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(line_ptr->number, 10000);

    // Test not finding a line at all.
    // In this case line_ptr should point to where the line would have been, i.e., line 256.
    find_line(15);
    ASSERT_NE(err, 0);
    ASSERT_EQ(line_ptr->number, 256);

    // Test finding a line that occurs earlier in the program.
    find_line(10000);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(line_ptr->number, 10000);
    find_line(10);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(line_ptr->number, 10);
}

void test_insert_or_update_line(void) {

    const char line_5_data[] = { 'E', 'N', 'D' };
    const char line_10_data[] = { 'P', 'R', 'I', 'N', 'T', ' ', '1' };
    const char line_200_data[] = { 'P', 'R', 'I', 'N', 'T', ' ', '3', '.', '1', '4', '1', '5', '9' };

    PRINT_TEST_NAME();

    initialize_program();

    set_line(10, line_10_data, sizeof line_10_data);
    insert_or_update_line();
    ASSERT_EQ(err, 0);
    reset_line_ptr();
    ASSERT_EQ(line_ptr->next_line_offset, sizeof (Line) + sizeof line_10_data);  
    ASSERT_EQ(line_ptr->number, 10);    
    ASSERT_MEMORY_EQ(line_ptr->data, line_10_data, sizeof line_10_data);  
    
    advance_line_ptr();
    ASSERT_EQ(line_ptr->next_line_offset, sizeof (Line));    
    ASSERT_EQ(line_ptr->number, -1);    

    set_line(200, line_200_data, sizeof line_200_data);
    insert_or_update_line();
    ASSERT_EQ(err, 0);
    reset_line_ptr();
    ASSERT_EQ(line_ptr->next_line_offset, sizeof (Line) + sizeof line_10_data);    
    ASSERT_EQ(line_ptr->number, 10);    
    advance_line_ptr();
    ASSERT_EQ(line_ptr->next_line_offset, sizeof (Line) + sizeof line_200_data);    
    ASSERT_EQ(line_ptr->number, 200);    
    advance_line_ptr();
    ASSERT_EQ(line_ptr->next_line_offset, sizeof (Line));    
    ASSERT_EQ(line_ptr->number, -1);    

    // Test inserting a line before the other two.
    set_line(5, line_5_data, sizeof line_5_data);
    insert_or_update_line();
    ASSERT_EQ(err, 0);
    reset_line_ptr();
    ASSERT_EQ(line_ptr->next_line_offset, sizeof (Line) + sizeof line_5_data);    
    ASSERT_EQ(line_ptr->number, 5);    
    advance_line_ptr();
    ASSERT_EQ(line_ptr->next_line_offset, sizeof (Line) + sizeof line_10_data);    
    ASSERT_EQ(line_ptr->number, 10);    
    advance_line_ptr();
    ASSERT_EQ(line_ptr->next_line_offset, sizeof (Line) + sizeof line_200_data);    
    ASSERT_EQ(line_ptr->number, 200);    
    advance_line_ptr();
    ASSERT_EQ(line_ptr->next_line_offset, sizeof (Line));    
    ASSERT_EQ(line_ptr->number, -1);    

    // Test deleting a line.
    set_line(200, line_200_data, 0);
    insert_or_update_line();
    ASSERT_EQ(err, 0);
    reset_line_ptr();
    ASSERT_EQ(line_ptr->next_line_offset, sizeof (Line) + sizeof line_5_data);    
    ASSERT_EQ(line_ptr->number, 5);    
    advance_line_ptr();
    ASSERT_EQ(line_ptr->next_line_offset, sizeof (Line) + sizeof line_10_data);    
    ASSERT_EQ(line_ptr->number, 10);    
    advance_line_ptr();
    ASSERT_EQ(line_ptr->next_line_offset, sizeof (Line));    
    ASSERT_EQ(line_ptr->number, -1);    
}

int main(void) {
    initialize_target();
    test_initalize_program();
    test_reset_line_ptr();
    test_advance_line_ptr();
    test_grow();
    test_shrink();
    test_find_line();
    test_insert_or_update_line();
    return 0;
}