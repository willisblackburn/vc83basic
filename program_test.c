#include "test.h"

static void test_initalize_program(void) {
    PRINT_TEST_NAME();

    initialize_program();

    ASSERT_EQ(line_ptr, program_ptr);
    ASSERT_EQ(line_ptr->number, -1);
    ASSERT_EQ(line_ptr->length, 0);
    ASSERT_EQ(heap_ptr, (void*)(program_ptr + 1)); // sizeof *program_ptr == size of the line header
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

    // Calling advance_line_ptr on the empty program should advance line_ptr to heap_ptr.
    initialize_program();
    advance_line_ptr();
    ASSERT_EQ((void*)line_ptr, heap_ptr);

    // If we put in a fake line with various lengths then line_ptr should advance by that much plus the header.
    initialize_program();
    line_ptr->length = 10;
    advance_line_ptr();
    ASSERT_EQ((char*)line_ptr, (char*)program_ptr + 13);
    line_ptr->length = 250;
    advance_line_ptr();
    ASSERT_EQ((char*)line_ptr, (char*)program_ptr + 13 + 253);
}

static void test_find_line(void) {
    int err;

    PRINT_TEST_NAME();

    initialize_program();

    ASSERT_EQ(line_ptr, program_ptr);

    // Add three lines: 10, 256, and 10000.
    // It doesn't matter what the actual line data is since we're not going to execute it.
    line_ptr->number = 10;
    line_ptr->length = 5;

    // Since we know advance_line_ptr works, we can use it to move to the next space in memory.
    // Note that we're charging into unallocated memory here, but that's okay since we own memory space
    // after the BSS.
    advance_line_ptr();
    line_ptr->number = 256;
    line_ptr->length = 250;
    advance_line_ptr();
    line_ptr->number = 10000;
    line_ptr->length = 10;
    advance_line_ptr();
    line_ptr->number = -1;
    line_ptr->length = 0;
    // Patch up the program end.
    advance_line_ptr();
    heap_ptr = line_ptr;

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

static void test_insert_or_update_line(void) {
    int err;

    PRINT_TEST_NAME();

    initialize_program();

    strcpy(buffer, "10 PRINT 1");
    buffer_length = 10;
    fprintf(stderr, "program_ptr = %p, heap_ptr=%p\n", program_ptr, heap_ptr);
    err = insert_or_update_line(10, 3);
    ASSERT_EQ(err, 0);
    reset_line_ptr();
    ASSERT_EQ(line_ptr->number, 10);    
    ASSERT_EQ(line_ptr->length, 7);  
    ASSERT_MEMORY_EQ(line_ptr->data, "PRINT 1", line_ptr->length);  
    
    advance_line_ptr();
    ASSERT_EQ(line_ptr->number, -1);    

    strcpy(buffer, "200 PRINT 3.14159");
    buffer_length = 16;
    fprintf(stderr, "program_ptr = %p, heap_ptr=%p\n", program_ptr, heap_ptr);
    err = insert_or_update_line(200, 4);
    ASSERT_EQ(err, 0);
    reset_line_ptr();
    ASSERT_EQ(line_ptr->number, 10);    
    ASSERT_EQ(line_ptr->length, 7);    
    advance_line_ptr();
    ASSERT_EQ(line_ptr->number, 200);    
    ASSERT_EQ(line_ptr->length, 12);    
    advance_line_ptr();
    ASSERT_EQ(line_ptr->number, -1);    

    // Test inserting a line before the other two.
    strcpy(buffer, "5 END");
    buffer_length = 5;
    err = insert_or_update_line(5, 2);
    ASSERT_EQ(err, 0);
    reset_line_ptr();
    ASSERT_EQ(line_ptr->number, 5);    
    ASSERT_EQ(line_ptr->length, 3);    
    advance_line_ptr();
    ASSERT_EQ(line_ptr->number, 10);    
    ASSERT_EQ(line_ptr->length, 7);    
    advance_line_ptr();
    ASSERT_EQ(line_ptr->number, 200);    
    ASSERT_EQ(line_ptr->length, 12);    
    advance_line_ptr();
    ASSERT_EQ(line_ptr->number, -1);    

    // Test deleting a line.
    strcpy(buffer, "200");
    buffer_length = 3;
    err = insert_or_update_line(200, 3);
    ASSERT_EQ(err, 0);
    reset_line_ptr();
    ASSERT_EQ(line_ptr->number, 5);    
    ASSERT_EQ(line_ptr->length, 3);    
    advance_line_ptr();
    ASSERT_EQ(line_ptr->number, 10);    
    ASSERT_EQ(line_ptr->length, 7);    
    advance_line_ptr();
    ASSERT_EQ(line_ptr->number, -1);    
}

int main(void) {
    initialize_target();
    test_initalize_program();
    test_reset_line_ptr();
    test_advance_line_ptr();
    test_find_line();
    test_insert_or_update_line();
    return 0;
}