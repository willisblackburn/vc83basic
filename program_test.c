#include "test.h"

static void test_initalize_program(void) {
    PRINT_TEST_NAME();

    initialize_program();

    ASSERT_EQ(program_start, line_ptr);
    ASSERT_EQ(line_ptr->number, -1);
    ASSERT_EQ(line_ptr->length, 0);
    ASSERT_EQ(program_end, program_start + 1);
}

int main(void) {
    test_initalize_program();
    return 0;
}