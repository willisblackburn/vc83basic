#ifndef _TEST_H

#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>

#include "../constants.h"

// Types
// These are not the actual types used by the interpeter! They are C structs that mirror the structures used in
// the assembly language code in order to make unit testing easier.

typedef struct Line {
    char next_line_offset;
    int number;
    char data[];
} Line;

typedef struct Float {
    unsigned long t;
    char e;
} Float;

typedef struct UnpackedFloat {
    unsigned long t;
    char e;
    char s;
} UnpackedFloat;

// Zero Page

#include "../zeropage.h"

// References to exports defined in c_wrappers.s

extern int AX;
extern char A;
extern char X;
extern char Y;

extern char err;

extern int BC;
#pragma zpsym ("BC")
extern int DE;
#pragma zpsym ("DE")
extern unsigned long FP0t;
#pragma zpsym ("FP0t")
extern char FP0e;
#pragma zpsym ("FP0e")
extern char FP0s;
#pragma zpsym ("FP0s")
extern unsigned long FP1t;
#pragma zpsym ("FP1t")
extern char FP1e;
#pragma zpsym ("FP1e")
extern char FP1s;
#pragma zpsym ("FP1s")

extern char buffer[];
extern Line line_buffer;

extern const char statement_name_table[];

// Prototypes for C wrapper functions

// decode.s
void decode_expression(/* AX */ void** vector_table_ptr);
int decode_number(void);
void decode_name(void);
char decode_operator(void);
char decode_unary_operator(void);
char decode_byte(void);

// encode.s
void encode_byte(/* A */ char value);

// expression.s
void evaluate_expression(void);
void push_value(/* AX */ int value);
int pop_value(void);
char stack_alloc(/* A */ char size);
void stack_free(/* A */ char size);


// fp.s
void load_fpx(/* X */ UnpackedFloat* fpx, /* AY */ const Float* value);
void store_fpx(/* X */ const UnpackedFloat* fpx, /* AY */ Float* value);
void swap_fp0_fp1(void);
void int_to_fp(/* AX */ int value);
void int32_to_fp(void);
int truncate_fp_to_int(void);
void truncate_fp_to_int32(void);
void fp_to_string(void);
void string_to_fp(const char* ptr, char pos);
char char_to_digit(/* A */ char c);
void adjust_exponent(/* X */ char add, /* Y */ char subtract);
void normalize(void);
void fadd(void);
void fsub(void);
void fmul(void);
void fdiv(void);
void fneg(void);
int fcmp(void);

// list.s
void list_line(void);
void list_statement(void);
void list_directive(/* A */ char directive);

// name.s
char find_name(/* AX */ const char* name_ptr);
void initialize_name_ptr(void* name_ptr);
void advance_name_ptr(void);
void add_variable(size_t data_size);

// parser.s
void parse_line(void);
void parse_statement(/* AX */ const char* match_ptr);
void parse_directive(/* A */ char directive);
void parse_expression(void);
void parse_name(void);
void parse_number(void);
void parse_argument_separator(void);

// program.s
void initialize_target(void);
void initialize_program(void);
void reset_next_line_ptr(void);
void find_line(/* AX */ int line_number);
void advance_next_line_ptr(void);
void insert_or_update_line(void);
void grow(/* Y */ void* ptr, /* AX */ size_t size);
void shrink(/* Y */ void* ptr, /* AX */ size_t size);

// util.s
void copy(/* AX */ size_t size);
void reverse_copy(/* AX */ size_t size);
void clear_memory(/* AX */ size_t size);
int mul2(/* AX */ int value);
int mul10(/* AX */ int value);
int div10(/* AX */ int value);
int invoke_indexed_vector(/* AX */ void* vectors, /* Y */ char index);
int read_number(const char* ptr, char pos);
void format_number(/* AX */ int number);

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
    line_pos = (char)offsetof(Line, data);
}

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

#define POSITIVE ((char)0x00)
#define NEGATIVE ((char)0x80)

#define SET_FPX(fpx, s_value, e_value, t_value) do { \
    fpx.s = (s_value); \
    fpx.e = (e_value); \
    fpx.t = (t_value); \
} while (0)

#define ASSERT_FPX_EQ(fpx, s_value, e_value, t_value) do { \
    ASSERT_EQ(fpx.s, s_value); \
    ASSERT_EQ(fpx.e, e_value); \
    ASSERT_EQ(fpx.t, t_value); \
} while (0)

#define SET_FLOAT(value, e_value, t_value) do { \
    value.e = (e_value); \
    value.t = (t_value); \
} while (0)

#define ASSERT_FLOAT_EQ(value, e_value, t_value) do { \
    ASSERT_EQ(value.e, e_value); \
    ASSERT_EQ(value.t, t_value); \
} while (0)

#endif
