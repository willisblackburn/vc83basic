#include "test.h"

void test_load_sy(void) {

    const String s = { 5, { 'H', 'E', 'L', 'L', 'O' }};
    char length;

    PRINT_TEST_NAME();

    S0 = NULL;
    S1 = NULL;

    length = load_sy(&S0, &s);
    ASSERT_PTR_EQ(S0, &s.data);
    ASSERT_EQ(length, s.length);
    ASSERT_NULL(S1);

    length = load_sy(&S1, &s);
    ASSERT_PTR_EQ(S1, &s.data);
    ASSERT_EQ(length, s.length);

    // Test the null case

    length = load_sy(&S0, NULL);
    ASSERT_EQ(length, 0);
}

void test_string_alloc(void) {
    void* original_string_ptr;
    const String* s;

    PRINT_TEST_NAME();

    initialize_program();

    original_string_ptr = string_ptr;
    s = string_alloc(10);
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
    const String* s;
    const String* leftover;
    size_t expect_length = strlen(expect_string_data);
    fprintf(stderr, "  %s:%d: read_string(input=\"%s\")\n", __FILE__, line, input);
    strcpy(buffer, input);
    s = read_string(buffer, 0);
    // Check the returned string.
    ASSERT_EQ(err, 0);
    HEXDUMP(s, sizeof (String) + expect_length);
    ASSERT_EQ(s->length, expect_length);
    ASSERT_EQ(memcmp(s->data, expect_string_data, s->length), 0);
    // Check the leftover string.
    leftover = (const String*)((const char*)s + STRING_EXTRA + s->length);
    ASSERT_EQ(leftover->length, 255 - s->length);
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

void test_compact(void) {
    const String* s;

    PRINT_TEST_NAME();

    initialize_program();

    // Sanity check before we get on with the test.
    ASSERT_PTR_EQ(string_ptr, himem_ptr);

    // No strings exist. Calling compact should do nothing.

    compact();
    ASSERT_PTR_EQ(string_ptr, himem_ptr);

    // Allocate one string but no variables. Should collect the space.

    s = string_alloc(10);
    ASSERT_PTR_EQ(string_ptr, (char*)himem_ptr - 13);
    compact();
    ASSERT_PTR_EQ(string_ptr, himem_ptr);
}

int main(void) {
    initialize_target();
    test_load_sy();
    test_string_alloc();
    test_read_string();
    test_compact();
    return 0;
}
