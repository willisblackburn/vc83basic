#include "test.h"

static void test_initalize_program(void) {
    PRINT_TEST_NAME();

    initialize_program();

    ASSERT_EQ(line_ptr, program_ptr);
    ASSERT_EQ(line_ptr->next_line_offset, sizeof (Line));
    ASSERT_EQ(line_ptr->number, -1);
    ASSERT_EQ((void*)variable_name_table_ptr, (void*)(program_ptr + 1)); // sizeof *program_ptr == size of the line header
    ASSERT_EQ((void*)value_table_ptr, (void*)(variable_name_table_ptr + 1)); // Variable name table is empty with terminating 0
    ASSERT_EQ(*variable_name_table_ptr, 0);
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

static void test_find_line(void) {
    int err;

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
    variable_name_table_ptr = (const char*)line_ptr;
    value_table_ptr = line_ptr;

    // Test if we can find each line separately.
    err = find_line(10);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(line_ptr->number, 10);
    err = find_line(256);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(line_ptr->number, 256);
    err = find_line(10000);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(line_ptr->number, 10000);

    // Test not finding a line at all.
    // In this case line_ptr should point to where the line would have been, i.e., line 256.
    err = find_line(15);
    ASSERT_NE(err, 0);
    ASSERT_EQ(line_ptr->number, 256);

    // Test finding a line that occurs earlier in the program.
    err = find_line(10000);
    ASSERT_EQ(line_ptr->number, 10000);
    ASSERT_EQ(err, 0);
    err = find_line(10);
    ASSERT_NE(err, 1);
    ASSERT_EQ(line_ptr->number, 10);
}

static void set_line_buffer(int number, const char* data, char data_length) {
    line_buffer.next_line_offset = (line_buffer.data + data_length) - (const char*)&line_buffer;
    line_buffer.number = number;
    memcpy(line_buffer.data, data, data_length);
}

static void test_insert_or_update_line(void) {
    int err;
    const char line_5_data[] = { 'E', 'N', 'D' };
    const char line_10_data[] = { 'P', 'R', 'I', 'N', 'T', ' ', '1' };
    const char line_200_data[] = { 'P', 'R', 'I', 'N', 'T', ' ', '3', '.', '1', '4', '1', '5', '9' };

    PRINT_TEST_NAME();

    initialize_program();

    set_line_buffer(10, line_10_data, sizeof line_10_data);
    err = insert_or_update_line();
    ASSERT_EQ(err, 0);
    reset_line_ptr();
    ASSERT_EQ(line_ptr->next_line_offset, sizeof (Line) + sizeof line_10_data);  
    ASSERT_EQ(line_ptr->number, 10);    
    ASSERT_MEMORY_EQ(line_ptr->data, line_10_data, sizeof line_10_data);  
    
    advance_line_ptr();
    ASSERT_EQ(line_ptr->number, -1);    

    set_line_buffer(200, line_200_data, sizeof line_200_data);
    err = insert_or_update_line();
    ASSERT_EQ(err, 0);
    reset_line_ptr();
    ASSERT_EQ(line_ptr->next_line_offset, 10);    
    ASSERT_EQ(line_ptr->number, 10);    
    advance_line_ptr();
    ASSERT_EQ(line_ptr->next_line_offset, sizeof (Line) + sizeof line_200_data);    
    ASSERT_EQ(line_ptr->number, 200);    
    advance_line_ptr();
    ASSERT_EQ(line_ptr->number, -1);    

    // Test inserting a line before the other two.
    set_line_buffer(5, line_5_data, sizeof line_5_data);
    err = insert_or_update_line();
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
    ASSERT_EQ(line_ptr->number, -1);    

    // Test deleting a line.
    set_line_buffer(200, line_200_data, 0);
    err = insert_or_update_line();
    ASSERT_EQ(err, 0);
    reset_line_ptr();
    ASSERT_EQ(line_ptr->next_line_offset, 6);    
    ASSERT_EQ(line_ptr->number, 5);    
    advance_line_ptr();
    ASSERT_EQ(line_ptr->next_line_offset, 10);    
    ASSERT_EQ(line_ptr->number, 10);    
    advance_line_ptr();
    ASSERT_EQ(line_ptr->number, -1);    
}

static void test_set_variable_value_ptr(void) {
    PRINT_TEST_NAME();

    initialize_program();

    set_variable_value_ptr(0);
    ASSERT_EQ(variable_value_ptr, (void*)((int*)value_table_ptr));
    set_variable_value_ptr(1);
    ASSERT_EQ(variable_value_ptr, (void*)((int*)value_table_ptr + 1));
    set_variable_value_ptr(127);
    ASSERT_EQ(variable_value_ptr, (void*)((int*)value_table_ptr + 127));
    // Should clear high bit if set
    set_variable_value_ptr(255);
    ASSERT_EQ(variable_value_ptr, (void*)((int*)value_table_ptr + 127));
}

int main(void) {
    initialize_target();
    test_initalize_program();
    test_reset_line_ptr();
    test_advance_line_ptr();
    test_find_line();
    test_insert_or_update_line();
    test_set_variable_value_ptr();
    return 0;
}