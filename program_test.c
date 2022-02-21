#include "test.h"

static void test_initalize_program(void) {
    PRINT_TEST_NAME();

    initialize_program();

    ASSERT_EQ(line_ptr, program_start);
    ASSERT_EQ(line_ptr->number, -1);
    ASSERT_EQ(line_ptr->length, 0);
    ASSERT_EQ(program_end, program_start + 1); // sizeof *program_start == size of the line header
}

static void test_reset_line_ptr(void) {
    PRINT_TEST_NAME();

    initialize_program();

    // After altering line_ptr, reset_line_ptr should set it back.
    line_ptr = 0;
    reset_line_ptr();

    ASSERT_EQ(line_ptr, program_start);
}

static void test_advance_line_ptr(void) {
    PRINT_TEST_NAME();

    // Calling advance_line_ptr on the empty program should advance line_ptr to program_end.
    initialize_program();
    advance_line_ptr();
    ASSERT_EQ(line_ptr, program_end);

    // If we put in a fake line with various lengths then line_ptr should advance by that much plus the header.
    initialize_program();
    line_ptr->length = 10;
    advance_line_ptr();
    ASSERT_EQ((char*)line_ptr, (char*)program_start + 13);
    line_ptr->length = 250;
    advance_line_ptr();
    ASSERT_EQ((char*)line_ptr, (char*)program_start + 13 + 253);
}

static void test_find_line(void) {
    int result;

    PRINT_TEST_NAME();

    initialize_program();

    ASSERT_EQ(line_ptr, program_start);

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
    program_end = line_ptr;

    // Test if we can find each line separately.
    reset_line_ptr();

    result = find_line(10);
    ASSERT_EQ(result, 0);
    ASSERT_EQ(line_ptr->number, 10);
    reset_line_ptr();
    result = find_line(256);
    ASSERT_EQ(result, 0);
    ASSERT_EQ(line_ptr->number, 256);
    reset_line_ptr();
    result = find_line(10000);
    ASSERT_EQ(result, 0);
    ASSERT_EQ(line_ptr->number, 10000);

    // Test finding the lines in sequence.
    reset_line_ptr();
    result = find_line(10);
    ASSERT_EQ(result, 0);
    ASSERT_EQ(line_ptr->number, 10);
    result = find_line(256);
    ASSERT_EQ(result, 0);
    ASSERT_EQ(line_ptr->number, 256);
    result = find_line(10000);
    ASSERT_EQ(result, 0);
    ASSERT_EQ(line_ptr->number, 10000);

    // Test not finding a line at all.
    reset_line_ptr();
    result = find_line(15);
    ASSERT_NE(result, 0);

    // Test finding a line that occurs earlier in the program.
    reset_line_ptr();
    result = find_line(10000);
    ASSERT_EQ(result, 0);
    result = find_line(10);
    ASSERT_NE(result, 0);
}

int main(void) {
    initialize_arch();
    test_initalize_program();
    test_reset_line_ptr();
    test_advance_line_ptr();
    test_find_line();
    return 0;
}