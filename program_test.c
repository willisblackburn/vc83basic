#include "test.h"

static void test_initalize_program(void) {
    PRINT_TEST_NAME();

    initialize_program();

    ASSERT_EQ(line_ptr, program_ptr);
    ASSERT_EQ(line_ptr->next_line_offset, sizeof (Line));
    ASSERT_EQ(line_ptr->number, -1);
    ASSERT_EQ((void*)free_ptr, (void*)(program_ptr + 1)); // sizeof *program_ptr == size of the line header
    ASSERT_LT((void*)free_ptr, (void*)himem_ptr);
}

static void test_reset_line_ptr(void) {
    PRINT_TEST_NAME();

    initialize_program();

    // After altering line_ptr, reset_line_ptr should set it back.
    line_ptr = NULL;
    reset_line_ptr();

    ASSERT_EQ(line_ptr, program_ptr);
}

static void test_advance_line_ptr(void) {
    PRINT_TEST_NAME();

    // Calling advance_line_ptr on the empty program should advance line_ptr to free_ptr.
    initialize_program();
    advance_line_ptr();
    ASSERT_EQ((void*)line_ptr, (void*)free_ptr);

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

static void test_find_line(void) {

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

    // Test if we can find each line separately.
    find_line_ax(10);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(line_ptr->number, 10);
    find_line_ax(256);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(line_ptr->number, 256);
    find_line_ax(10000);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(line_ptr->number, 10000);

    // Test not finding a line at all.
    // In this case line_ptr should point to where the line would have been, i.e., line 256.
    find_line_ax(15);
    ASSERT_NE(err, 0);
    ASSERT_EQ(line_ptr->number, 256);

    // Test finding a line that occurs earlier in the program.
    find_line_ax(10000);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(line_ptr->number, 10000);
    find_line_ax(10);
    ASSERT_NE(err, 1);
    ASSERT_EQ(line_ptr->number, 10);
}

static void test_insert_or_update_line(void) {

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

static void test_check_himem(void) {

    PRINT_TEST_NAME();

    free_ptr = (void*)0x1000;
    himem_ptr = (void*)0x2000;

    check_himem(0x0F00);
    ASSERT_EQ(err, 0);

    check_himem(0x1F00);
    ASSERT_NE(err, 0);

    himem_ptr = (void*)0xFF00;

    check_himem(0xEF00);
    ASSERT_EQ(err, 0);

    check_himem(0xFF00);
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

    ASSERT_EQ(line_ptr, program_ptr);
    ASSERT_EQ(free_ptr, (void*)((char*)line_ptr + 9));

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

    ASSERT_EQ(line_ptr, program_ptr);
    ASSERT_EQ(free_ptr, (void*)((char*)line_ptr + 9 + 0x400));
}

static void test_shrink(void) {

    // To test shrink, we first grow some sections, write some data to them, then make sure that data is
    // preserved when we shrink. We know that grow works because it's been separately tested.

    PRINT_TEST_NAME();

    initialize_program();

    // Create some program space.
    grow(&line_ptr, 3);
    ASSERT_EQ(err, 0);
    program_ptr->next_line_offset = 3;
    program_ptr->number = 10;

    // Move free pointer up by 3 bytes.
    grow(&free_ptr, 3);
    line_ptr->next_line_offset = 3;
    line_ptr->number = 20;
    ASSERT_EQ(err, 0);

    // Make sure all the pointers are where they should be.
    ASSERT_EQ((char*)line_ptr, (char*)program_ptr + 3);
    ASSERT_EQ((char*)free_ptr, (char*)line_ptr + 6);

    // Now shrink each section, each time checking that no data is corrupted.

    shrink(&line_ptr, 3);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(line_ptr, program_ptr);
    ASSERT_EQ(line_ptr->number, 20);
    ASSERT_EQ((char*)free_ptr, (char*)line_ptr + 6);

    shrink(&free_ptr, 3);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(line_ptr, program_ptr);
    ASSERT_EQ((char *)free_ptr, (char*)line_ptr + 3);
}

int main(void) {
    initialize_target();
    test_initalize_program();
    test_reset_line_ptr();
    test_advance_line_ptr();
    test_find_line();
    test_insert_or_update_line();
    test_check_himem();
    test_calculate_bytes_to_move();
    test_grow();
    test_shrink();
    return 0;
}