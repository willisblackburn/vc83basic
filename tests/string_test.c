#include "test.h"

void test_load_s(void) {

    const String s = { 5, { 'H', 'E', 'L', 'L', 'O' }};
    char length;

    PRINT_TEST_NAME();

    S0 = NULL;
    S1 = NULL;

    length = load_s0(&s);
    ASSERT_PTR_EQ(S0, &s.data);
    ASSERT_EQ(length, s.length);
    ASSERT_NULL(S1);

    length = load_s1(&s);
    ASSERT_PTR_EQ(S1, &s.data);
    ASSERT_EQ(length, s.length);

    // Test the null case

    length = load_s0(NULL);
    ASSERT_EQ(length, 0);
}

void test_string_alloc(void) {
    void* original_string_ptr;
    const String* s;

    PRINT_TEST_NAME();

    initialize_program();

    original_string_ptr = string_ptr;
    DEBUG_PTR(original_string_ptr);
    s = string_alloc(10);
    DEBUG_PTR(s);
    ASSERT_EQ(err, 0);
    ASSERT_PTR_EQ(s, string_ptr);
    ASSERT_PTR_EQ(string_ptr, (char*)original_string_ptr - 10 - STRING_EXTRA);
    ASSERT_EQ(s->length, 10);

    s = string_alloc(20);
    ASSERT_EQ(err, 0);
    ASSERT_PTR_EQ(s, string_ptr);
    ASSERT_PTR_EQ(string_ptr, (char*)original_string_ptr - 10 - STRING_EXTRA - 20 - STRING_EXTRA);
    ASSERT_EQ(s->length, 20);
}

void call_read_string(const char* input, const char* expect_string_data, char expect_y, int line) {
    const String* leftover;
    size_t expect_length = strlen(expect_string_data);
    fprintf(stderr, "  %s:%d: read_string(input=\"%s\")\n", __FILE__, line, input);
    strcpy(buffer, input);
    read_string(buffer, 0);
    // Check the returned string.
    ASSERT_EQ(err, 0);
    HEXDUMP(string_ptr, sizeof (String) + expect_length);
    ASSERT_EQ(string_ptr->length, expect_length);
    ASSERT_EQ(memcmp(string_ptr->data, expect_string_data, string_ptr->length), 0);
    // Check the leftover string.
    leftover = (const String*)((const char*)string_ptr + STRING_EXTRA + string_ptr->length);
    ASSERT_EQ(leftover->length, 255 - string_ptr->length);
    // Make sure read position returned correctly.
    ASSERT_EQ(Y, expect_y);
}

void test_read_string(void) {
    PRINT_TEST_NAME();

    initialize_program();

    call_read_string("HELLO", "HELLO", 5, __LINE__);
    call_read_string("HELLO,WORLD", "HELLO", 5, __LINE__);
    call_read_string("\"HELLO\"", "HELLO", 7, __LINE__);
    call_read_string("HELLO\"", "HELLO\"", 6, __LINE__);
    call_read_string("\"\"", "", 2, __LINE__);
    call_read_string("\"\",IGNORE", "", 2, __LINE__);
    call_read_string(",IGNORE", "", 0, __LINE__);
    call_read_string("REPEATED\"\"CHARS", "REPEATED\"\"CHARS", 15, __LINE__);
    call_read_string("\"REPEATED\"\"CHARS\"", "REPEATED\"CHARS", 17, __LINE__);
}

int main(void) {
    initialize_target();
    test_load_s();
    test_string_alloc();
    test_read_string();
    return 0;
}
