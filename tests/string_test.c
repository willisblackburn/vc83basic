#include "test.h"

void add_string_variable_with_name(const char* name, const String* value) {
    parse_and_decode_name(name);
    find_name(variable_name_table_ptr);
    ASSERT_NE(err, 0);
    add_variable();
    // Now name_ptr points to the data allocated for the new variable, so we can cast and assign through it.
    *((const String**)name_ptr) = value;
    ASSERT_EQ(err, 0);
}

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

void test_compact(void) {
    const String* s;
    size_t offset;

    PRINT_TEST_NAME();

    initialize_program();

    // Sanity check before we get on with the test.
    ASSERT_PTR_EQ(string_ptr, himem_ptr);

    // No strings exist. Calling compact should do nothing.
    compact();
    ASSERT_PTR_EQ(string_ptr, himem_ptr);

    // Allocate one string but no variables. Should collect the space.
    string_alloc(10);
    ASSERT_EQ(err, 0);
    ASSERT_PTR_EQ(string_ptr, (char*)himem_ptr - 10 - STRING_EXTRA);
    compact();
    ASSERT_PTR_EQ(string_ptr, himem_ptr);

    // Same thing but two allocations.
    string_alloc(10);
    ASSERT_EQ(err, 0);
    string_alloc(120);
    ASSERT_EQ(err, 0);
    ASSERT_PTR_EQ(string_ptr, (char*)himem_ptr - 10 - STRING_EXTRA - 120 - STRING_EXTRA);
    compact();
    ASSERT_PTR_EQ(string_ptr, himem_ptr);

    // Between the two allocations, allocate another string and assign it to a variable.
    string_alloc(10);
    ASSERT_EQ(err, 0);
    s = string_alloc(5);
    ASSERT_EQ(err, 0);
    memcpy(s->data, "HELLO", 5);
    add_string_variable_with_name("A$", s);
    string_alloc(120);
    ASSERT_EQ(err, 0);
    ASSERT_PTR_EQ(string_ptr, (char*)himem_ptr - 10 - STRING_EXTRA - 5 - STRING_EXTRA - 120 - STRING_EXTRA);
    compact();
    // Only the "HELLO" string should remain.
    ASSERT_PTR_EQ(string_ptr, (char*)himem_ptr - 5 - STRING_EXTRA);
    // Check A$
    parse_and_decode_name("A$");
    find_name(variable_name_table_ptr);
    ASSERT_EQ(err, 0);
    s = *(const String**)name_ptr;
    ASSERT_PTR_EQ(s, (char*)himem_ptr - 5 - STRING_EXTRA);
    ASSERT_EQ(s->length, 5);
    ASSERT_EQ(memcmp(s->data, "HELLO", 5), 0);

    // Try some large strings.
    // Populate the string with values from 0 to 254 to verify they're copied correctly.
    string_alloc(255);
    ASSERT_EQ(err, 0);
    s = string_alloc(255);
    ASSERT_EQ(err, 0);
    for (offset = 0; offset < 255; offset++) {
        s->data[offset] = (char)offset;
    }
    add_string_variable_with_name("B$", s);
    string_alloc(10);
    ASSERT_EQ(err, 0);
    string_alloc(10);
    ASSERT_EQ(err, 0);
    compact();
    // string_ptr should point to B$.
    ASSERT_PTR_EQ(string_ptr, (char*)himem_ptr - 5 - STRING_EXTRA - 255 - STRING_EXTRA);
    // Check A$
    parse_and_decode_name("A$");
    find_name(variable_name_table_ptr);
    ASSERT_EQ(err, 0);
    s = *(const String**)name_ptr;
    ASSERT_EQ(s->length, 5);
    ASSERT_EQ(memcmp(s->data, "HELLO", 5), 0);
    // Check B$
    parse_and_decode_name("B$");
    find_name(variable_name_table_ptr);
    ASSERT_EQ(err, 0);
    s = *(const String**)name_ptr;
    ASSERT_EQ(s->length, 255);
    ASSERT_EQ(s->data[0], 0);
    ASSERT_EQ(s->data[1], 1);
    ASSERT_EQ(s->data[254], 254);
}

void test_compact_with_array(void) {
    const char line_data[] = { 'A', '$' | EOT, '(', '5', ')' };
    const String* hello;
    const String* world;
    char index;

    PRINT_TEST_NAME();

    initialize_program();

    // Don't repeat stuff from other tests; just get on with setting up an array.
    // We build the array by parsing an expression, since it's the simplest way to do it.

    // Look up A$ as an array
    set_line(0, line_data, sizeof line_data);
    decode_name();
    ASSERT_EQ(decode_name_type, TYPE_STRING);
    ASSERT_EQ(decode_name_arity, -1);
    index = find_name(array_name_table_ptr);
    ASSERT_NE(err, 0);
    ASSERT_EQ(index, 0);

    // Parse dimension values
    decode_name_arity = -evaluate_argument_list(0);

    // Make sure argument is on the stack
    ASSERT_EQ(stack_pos, PRIMARY_STACK_SIZE - 6);

    // Add as new array
    dimension_array();
    ASSERT_EQ(err, 0);

    HEXDUMP(array_name_table_ptr, 64);

    // Look up the name A$ again
    set_line(0, line_data, sizeof line_data);
    decode_name();
    index = find_name(array_name_table_ptr);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(index, 0);

    // name_ptr should point to the array data: array_name_table_ptr +
    //   2 for the 16-bit length
    //   2 for "A$"
    ASSERT_PTR_EQ(name_ptr, array_name_table_ptr + 4);

    // Advance 3 more bytes for the arity and the dimension length; now name_ptr is a String**
    name_ptr += 3;

    string_alloc(20);
    ASSERT_EQ(err, 0);
    hello = string_alloc(5);
    ASSERT_EQ(err, 0);
    memcpy(hello->data, "HELLO", 5);
    
    world = string_alloc(5);
    ASSERT_EQ(err, 0);
    memcpy(world->data, "WORLD", 5);
    
    ((const String**)name_ptr)[3] = hello;
    ((const String**)name_ptr)[4] = world;

    // Pre-compact, there are three strings with 30 bytes total plus 9 bytes overhead
    ASSERT_PTR_EQ(string_ptr, (char*)himem_ptr - 30 - 3 * STRING_EXTRA);

    compact();

    // Post-compact, there should be just the two 5-byte strings left
    ASSERT_PTR_EQ(string_ptr, (char*)himem_ptr - 10 - 2 * STRING_EXTRA);

    // Find the A$ array again
    set_line(0, line_data, sizeof line_data);
    decode_name();
    index = find_name(array_name_table_ptr);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(index, 0);

    name_ptr += 3;

    hello = ((const String**)name_ptr)[3];
    world = ((const String**)name_ptr)[4];

    ASSERT_EQ(hello->length, 5);
    ASSERT_MEMORY_EQ(hello->data, "HELLO", 5);
    ASSERT_EQ(world->length, 5);
    ASSERT_MEMORY_EQ(world->data, "WORLD", 5);
}

void test_compact_with_expression(void) {
    const String* hello;
    const String* world;
    const String* s;
    char index;

    PRINT_TEST_NAME();

    initialize_program();

    // Make sure that compact preserves strings that are only referenced from the expression stack.

    string_alloc(20);
    ASSERT_EQ(err, 0);
    hello = string_alloc(5);
    push_string();
    ASSERT_EQ(err, 0);
    memcpy(hello->data, "HELLO", 5);
    world = string_alloc(5);
    ASSERT_EQ(err, 0);
    memcpy(world->data, "WORLD", 5);
    push_string();

    // Pre-compact, there are three strings with 30 bytes total plus 9 bytes overhead
    ASSERT_PTR_EQ(string_ptr, (char*)himem_ptr - 30 - 3 * STRING_EXTRA);

    DEBUG_PTR(hello);
    DEBUG_PTR(world);

    compact();

    // Post-compact, there should be just the two 5-byte strings left
    ASSERT_PTR_EQ(string_ptr, (char*)himem_ptr - 10 - 2 * STRING_EXTRA);

    // Popping values should get the correct strings
    world = pop_string();
    hello = pop_string();

    DEBUG_PTR(hello);
    DEBUG_PTR(world);

    ASSERT_EQ(hello->length, 5);
    ASSERT_MEMORY_EQ(hello->data, "HELLO", 5);
    ASSERT_EQ(world->length, 5);
    ASSERT_MEMORY_EQ(world->data, "WORLD", 5);
}

void test_string_alloc_retry(void) {
    const String* s;
    const String* s2;

    PRINT_TEST_NAME();

    initialize_program();

    // Set string_ptr and himem_ptr to be free_ptr plus 200. This permits just 200 bytes for strings, which the test
    // will exhaust unless the collector is able to reclaim the space I've allocated for strings but not used.

    string_ptr = himem_ptr = (char*)free_ptr + 200;

    // Allocate two 100-byte strings. The second one should force a GC of the first one and wind up at the same
    // address.

    s = string_alloc(100);
    ASSERT_EQ(err, 0);
    ASSERT_PTR_EQ(string_ptr, (char*)himem_ptr - 100 - STRING_EXTRA);
    ASSERT_PTR_EQ(s, string_ptr);
    s2 = string_alloc(100);
    ASSERT_EQ(err, 0);
    ASSERT_PTR_EQ(string_ptr, (char*)himem_ptr - 100 - STRING_EXTRA);
    ASSERT_PTR_EQ(s2, string_ptr);

    // Make sure small string survives after allocation failure.
    // HELLO$ will be allocated after surviving 100-byte string from above. Then compact will have to collect the
    // 100-byte string to make way for the new 100-byte string.

    s = string_alloc(5);
    ASSERT_EQ(err, 0);
    ASSERT_PTR_EQ(s, s2 - 5 - STRING_EXTRA);
    memcpy(s->data, "HELLO", 5);
    add_string_variable_with_name("HELLO$", s);

    // This allocation should discard s2, move "HELLO" up to the top of the string space, and allocate s beneath it.
    // Total usage should be 100 + 5 bytes plus STRING_EXTRA bytes overhead for each string = 111 bytes.

    s2 = string_alloc(100);
    ASSERT_EQ(err, 0);
    ASSERT_PTR_EQ(string_ptr, (char*)himem_ptr - 5 - STRING_EXTRA - 100 - STRING_EXTRA);
    ASSERT_PTR_EQ(s2, string_ptr);

    // Check HELLO$
    parse_and_decode_name("HELLO$");
    find_name(variable_name_table_ptr);
    ASSERT_EQ(err, 0);
    s = *(const String**)name_ptr;
    ASSERT_PTR_EQ(s, (char *)himem_ptr - 5 - STRING_EXTRA); // "HELLO" should still be at top of memory
    ASSERT_EQ(s->length, 5);
    ASSERT_EQ(memcmp(s->data, "HELLO", 5), 0);
}

int main(void) {
    initialize_target();
    test_load_s();
    test_string_alloc();
    test_read_string();
    test_compact();
    test_compact_with_array();
    test_string_alloc_retry();
    test_compact_with_expression();
    return 0;
}
