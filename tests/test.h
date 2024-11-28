#ifndef _TEST_H

#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>

// Types
// These are not the actual types used by the interpeter! They are C structs that mirror the structures used in
// the assembly language code in order to make unit testing easier.

typedef struct Line {
    char next_line_offset;
    int number;
    char data[];
} Line;

// Zero Page

extern char buffer_pos;
#pragma zpsym ("buffer_pos")
extern void* src_ptr;
#pragma zpsym ("src_ptr")
extern void* dst_ptr;
#pragma zpsym ("dst_ptr")
extern size_t size;
#pragma zpsym ("size")
extern Line* program_ptr;
#pragma zpsym ("program_ptr")
extern Line* line_ptr;
#pragma zpsym ("line_ptr")
extern void* free_ptr;
#pragma zpsym ("free_ptr")
extern void* himem_ptr;
#pragma zpsym ("himem_ptr")

// Data

extern char buffer[];
extern Line line_buffer;

// Used by c_wrappers.s

extern int reg_ax;
extern char reg_a;
extern char reg_x;
extern char reg_y;

extern char err;

// Prototypes for C wrapper functions

// parser.s
int read_number(void);
char char_to_digit(/* A */ char c);
void parse_keyword(/* AX */ const char* keyword);

// program.s
void initialize_target(void);
void initialize_program(void);
void reset_line_ptr(void);
void find_line(/* AX */ int line_number);
void advance_line_ptr(void);
void insert_or_update_line(void);
void grow(/* Y */ void* ptr, /* AX */ size_t size);
void shrink(/* Y */ void* ptr, /* AX */ size_t size);

// util.s
void copy(/* AX */ size_t size);
void reverse_copy(/* AX */ size_t size);
int mul10(/* AX */ int value);
int div10(/* AX */ int value);

#define HEXDUMP(data, length) hexdump(#data, (char*)(data), (length))

#define PRINT_TEST_NAME() fprintf(stderr, "%s:\n", __func__);

#define ASSERT(x) do { fprintf(stderr, "  %s:%u: assert %s: ", __FILE__, __LINE__, #x); assert(x); fputs("OK\n", stderr); } while (0)
#define ASSERT_OP(a, b, op) do { fprintf(stderr, "  %s:%u: assert %s (%ld, $%lX) %s %s (%ld, $%lX): ", __FILE__, __LINE__, #a, (long)(a), (long)(a), #op, #b, (long)(b), (long)(b)); assert((a) op (b)); fputs("OK\n", stderr); } while (0)
#define ASSERT_EQ(a, b) ASSERT_OP(a, b, ==)
#define ASSERT_NE(a, b) ASSERT_OP(a, b, !=)
#define ASSERT_LT(a, b) ASSERT_OP(a, b, <)
#define ASSERT_LE(a, b) ASSERT_OP(a, b, <=)
#define ASSERT_GT(a, b) ASSERT_OP(a, b, >)
#define ASSERT_GE(a, b) ASSERT_OP(a, b, >=)
#define ASSERT_PTR_OP(a, b, op) do { fprintf(stderr, "  %s:%u: assert %s ($%04X) %s %s ($%04X): ", __FILE__, __LINE__, #a, (a), #op, #b, (b)); assert((void*)(a) op (void*)(b)); fputs("OK\n", stderr); } while (0)
#define ASSERT_PTR_EQ(a, b) ASSERT_PTR_OP(a, b, ==)
#define ASSERT_PTR_NE(a, b) ASSERT_PTR_OP(a, b, !=)
#define ASSERT_PTR_LT(a, b) ASSERT_PTR_OP(a, b, <)
#define ASSERT_PTR_LE(a, b) ASSERT_PTR_OP(a, b, <=)
#define ASSERT_PTR_GT(a, b) ASSERT_PTR_OP(a, b, >)
#define ASSERT_PTR_GE(a, b) ASSERT_PTR_OP(a, b, >=)
#define ASSERT_STRING_EQ(a, b)  do { fprintf(stderr, "  %s:%u: assert \"%s\" == \"%s\": ", __FILE__, __LINE__, (a), (b)); assert(strcmp((a), (b)) == 0); fputs("OK\n", stderr); } while (0)
#define ASSERT_MEMORY_EQ(a, b, length)  do { fprintf(stderr, "  %s:%u: assert %u byte(s) memory equals:\n", __FILE__, __LINE__, (length)); HEXDUMP(a, length); HEXDUMP(b, length); assert(memcmp((a), (b), (length)) == 0); fputs("OK\n", stderr); } while (0)
#define ASSERT_IS_OR_IS_NOT_NULL(a, s, op) do { fprintf(stderr, "  %s:%u: assert %s ($%04X) %s NULL: ", __FILE__, __LINE__, #a, (a), s); assert((a) op NULL); fputs("OK\n", stderr); } while (0)
#define ASSERT_NULL(a) ASSERT_IS_OR_IS_NOT_NULL(a, "is", ==)
#define ASSERT_NOT_NULL(a) ASSERT_IS_OR_IS_NOT_NULL(a, "is not", !=)

#define DEBUG(x) fprintf(stderr, #x "=%d\n", (x))

#define HERE() fprintf(stderr, "%s:%d\n", __FILE__, __LINE__)

// Common functions and definitions used in tests

void hexdump(const char* name, const char* data, size_t length) {
    unsigned i, j;
    const char* p;
    fprintf(stderr, "        %s ($%04X):\n", name, data);
    for (i = 0; i < length; i += j) {
        fprintf(stderr, "        %04X %04X  ", i, data + i);
        p = data + i;
        for (j = 0; j < 16; j++, p++) {
            if (i + j < length) fprintf(stderr, "%02X ", *p);
            else fprintf(stderr, "   ");
        }
        fprintf(stderr, " ");
        p = data + i;
        for (j = 0; j < 16; j++, p++) {
            if (i + j < length) fputc(isprint(*p) ? *p : '.', stderr);
            else fputc(' ', stderr);
        }
        printf("\n");
    }
}

void set_line(int line, const char* data, size_t length) {
    line_buffer.number = line;
    line_buffer.next_line_offset = (char)(length + offsetof(Line, data));
    memcpy(line_buffer.data, data, length);
    line_ptr = &line_buffer;
}

#endif
