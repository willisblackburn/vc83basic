#ifndef _TEST_H

#include <assert.h>
#include <stdio.h>
#include <string.h>

// Types
// These are not the actual types used by the interpeter! They are C structs that mirror the structures used in
// the assembly language code in order to make unit testing easier.

typedef struct line {
    int number;
    char length;
    char data[];
} line;

// Zero Page

extern char status;
#pragma zpsym ("status")
extern char r;
#pragma zpsym ("r")
extern line* line_ptr;
#pragma zpsym ("line_ptr")

// Data

extern char buffer[];
extern char buffer_length;

extern line* program_ptr;
extern void* heap_ptr;

// Used by c_wrappers.s

extern int reg_ax;
extern char reg_a;
extern char reg_x;
extern char reg_y;

// Prototypes for C wrapper functions

void initialize_arch(void);
void initialize_program(void);
void reset_line_ptr(void);
int find_line(int line_number);
void advance_line_ptr(void);
int insert_or_update_line(int line_number, char r);
int read_number(char r);
int char_to_digit(char c);
int parse_keyword(const char* keyword, char r);
void copy_bytes(char* to, const char* from, size_t size);
void copy_bytes_back(char* to, const char* from, size_t size);
int mul10(int value);
int div10(int value);
// Common functions and definitions used in tests

static void set_buffer(const char* s) {
    // strcpy adds terminating 0 to string in buffer.
    strcpy(buffer, s);
    buffer_length = strlen(s);
}

static void hexdump(const char* name, const char* data, size_t length) {
    unsigned i = 0;
    fprintf(stderr, "        %s ($%04X):\n", name, data);
    while (i < length) {
        fprintf(stderr, "        %04x  ", i);
        do {
            fprintf(stderr, "%02x ", data[i++]);
        } while (i < length && (i % 16));
        printf("\n");
    }
}

#define HEXDUMP(data, length) hexdump(#data, (char*)(data), (length))

#define PRINT_TEST_NAME() fprintf(stderr, "%s:\n", __func__);

#define ASSERT_OP(a, b, op) do { fprintf(stderr, "  %u  assert %s (%ld, $%lX) %s %s (%ld, $%lX): ", __LINE__, #a, (long)(a), (long)(a), #op, #b, (long)(b), (long)(b)); assert((a) op (b)); fputs("OK\n", stderr); } while (0)
#define ASSERT_EQ(a, b) ASSERT_OP(a, b, ==)
#define ASSERT_NE(a, b) ASSERT_OP(a, b, !=)
#define ASSERT_LT(a, b) ASSERT_OP(a, b, <)
#define ASSERT_LE(a, b) ASSERT_OP(a, b, <=)
#define ASSERT_GT(a, b) ASSERT_OP(a, b, >)
#define ASSERT_GE(a, b) ASSERT_OP(a, b, >=)
#define ASSERT_STRING_EQ(a, b)  do { fprintf(stderr, "  %u  assert \"%s\" == \"%s\": ", __LINE__, (a), (b)); assert(strcmp((a), (b)) == 0); fputs("OK\n", stderr); } while (0)
#define ASSERT_MEMORY_EQ(a, b, length)  do { fprintf(stderr, "  %u  assert memory equals:\n", __LINE__); HEXDUMP(a, length); HEXDUMP(b, length); assert(memcmp((a), (b), (length)) == 0); fputs("OK\n", stderr); } while (0)
#define ASSERT_IS_OR_IS_NOT_NULL(a, s, op) do { fprintf(stderr, "  %u  assert %s (%u, $%X) %s NULL: ", __LINE__, #a, (a), (a), s); assert((a) op NULL); fputs("OK\n", stderr); } while (0)
#define ASSERT_NULL(a) ASSERT_IS_OR_IS_NOT_NULL(a, "is", ==)
#define ASSERT_NOT_NULL(a) ASSERT_IS_OR_IS_NOT_NULL(a, "is not", !=)

#endif
