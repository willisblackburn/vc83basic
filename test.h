#ifndef _TEST_H

#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>

#include "constants.h"

// Types
// These are not the actual types used by the interpeter! They are C structs that mirror the structures used in
// the assembly language code in order to make unit testing easier.

typedef struct Line {
    char next_line_offset;
    int number;
    char data[];
} Line;

typedef struct Float {
    signed char e;
    long s;
} Float;

// Zero Page

extern Float reg_fpa;
#pragma zpsym ("reg_fpa")
extern char bp;
#pragma zpsym ("bp")
extern char lp;
#pragma zpsym ("lp")
extern void* src_ptr;
#pragma zpsym ("src_ptr")
extern void* dst_ptr;
#pragma zpsym ("dst_ptr")
extern void** vector_table_ptr;
#pragma zpsym ("vector_table_ptr")
extern char* name_ptr;
#pragma zpsym ("name_ptr")
extern char np;
#pragma zpsym ("np")
extern Line* program_ptr;
#pragma zpsym ("program_ptr")
extern Line* line_ptr;
#pragma zpsym ("line_ptr")
extern Line* next_line_ptr;
#pragma zpsym ("next_line_ptr")
extern char* variable_name_table_ptr;
#pragma zpsym ("variable_name_table_ptr")
extern void* value_table_ptr;
#pragma zpsym ("value_table_ptr")
extern void* free_ptr;
#pragma zpsym ("free_ptr")
extern void* himem_ptr;
#pragma zpsym ("himem_ptr")
extern char variable_count;
#pragma zpsym ("variable_count")
extern void* variable_value_ptr;
#pragma zpsym ("variable_value_ptr")
extern char osp;
#pragma zpsym ("osp")
extern char psp;
#pragma zpsym ("psp")

// Data

extern char buffer[];
extern Line line_buffer;

extern const char statement_name_table[];

// Used by c_wrappers.s

extern int reg_ax;
extern char reg_a;
extern char reg_x;
extern char reg_y;

// Prototypes for C wrapper functions

// decode.s
void decode_expression(void** vector_table_ptr);
void decode_number(void);
char decode_variable(void);
char decode_operator(void);
char decode_unary_operator(void);
char decode_byte(void);

// expression.h
char evaluate_expression(void);
char push_fpa(void);
void pop_fpa(void);
char stack_alloc(char size);
void stack_free(char size);

// encode.s
int encode_number(void);
int encode_byte(char value);

// fp.s
void load_fpa(const Float* value);
void store_fpa(Float* value);
void clear_fpa(void);
void swap_fpa(Float* value);
int fpa_is_zero(void);
void fneg(void);
void fp_to_string(void);
int string_to_fp(void);
int char_to_digit(char c);
void int_to_fp(int value);
int truncate_fp_to_int(void);
void fadd(const Float* value);
void fsub(const Float* value);
void fmul(const Float* value);
void fdiv(const Float* value);

// list.s
int list_line(const void* line_ptr);
void list_element(const char* name_ptr, char index, const void* line_ptr, char lp, char bp);
void list_directive(char directive, const void* line_ptr, char lp, char bp);

// name.s
int find_name(const char* name_ptr, char bp);
int is_name_character(char c);
int get_name_table_entry(const char* name_ptr, char index);
int add_variable(void);

// parser.s
int parse_line(void);
int parse_element(const char* name_ptr, char bp, char lp);
int parse_directive(char directive, char bp, char lp);
int parse_expression(char bp, char lp);
int parse_argument_separator(char bp);

// program.s
void initialize_target(void);
void initialize_program(void);
void reset_next_line_ptr(void);
int find_line(int line_number);
void advance_next_line_ptr(void);
int insert_or_update_line(void);
int expand(void* ptr, size_t size);
int compact(void* ptr, size_t size);
size_t calculate_bytes_to_move(void);
int check_himem(size_t size);
void set_variable_value_ptr(char variable);

// util.s
void copy_bytes(char* to, const char* from, size_t size);
void copy_bytes_higher(char* to, const char* from, size_t size);
void clear_memory(char* p, size_t size);
int mul8(int value);
int invoke_indexed_vector(void* vectors, char index);

// Common functions and definitions used in tests

void hexdump(const char* name, const char* data, size_t length) {
    unsigned i, j;
    const char* p;
    fprintf(stderr, "        %s ($%04X):\n", name, data);
    for (i = 0; i < length; i += j) {
        fprintf(stderr, "        %04X %04X  ", i, data + i);
        p = data + i;
        for (j = 0; j < 16; j++, p++) {
            fprintf(stderr, "%02X ", *p);
        }
        fprintf(stderr, " ");
        p = data + i;
        for (j = 0; j < 16; j++, p++) {
            fputc(isprint(*p) ? *p : '.', stderr);
        }
        printf("\n");
    }
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
#define ASSERT_PTR_OP(a, b, op) do { fprintf(stderr, "  %s:%u: assert %s ($%lX) %s %s ($%lX): ", __FILE__, __LINE__, #a, (long)(a), #op, #b, (long)(b)); assert((void*)(a) op (void*)(b)); fputs("OK\n", stderr); } while (0)
#define ASSERT_PTR_EQ(a, b) ASSERT_PTR_OP(a, b, ==)
#define ASSERT_PTR_NE(a, b) ASSERT_PTR_OP(a, b, !=)
#define ASSERT_PTR_LT(a, b) ASSERT_PTR_OP(a, b, <)
#define ASSERT_PTR_LE(a, b) ASSERT_PTR_OP(a, b, <=)
#define ASSERT_PTR_GT(a, b) ASSERT_PTR_OP(a, b, >)
#define ASSERT_PTR_GE(a, b) ASSERT_PTR_OP(a, b, >=)
#define ASSERT_STRING_EQ(a, b)  do { fprintf(stderr, "  %s:%u: assert \"%s\" == \"%s\": ", __FILE__, __LINE__, (a), (b)); assert(strcmp((a), (b)) == 0); fputs("OK\n", stderr); } while (0)
#define ASSERT_MEMORY_EQ(a, b, length)  do { fprintf(stderr, "  %s:%u: assert %u byte(s) memory equals:\n", __FILE__, __LINE__, (length)); HEXDUMP(a, length); HEXDUMP(b, length); assert(memcmp((a), (b), (length)) == 0); fputs("OK\n", stderr); } while (0)
#define ASSERT_IS_OR_IS_NOT_NULL(a, s, op) do { fprintf(stderr, "  %s:%u: assert %s (%u, $%X) %s NULL: ", __FILE__, __LINE__, #a, (a), (a), s); assert((a) op NULL); fputs("OK\n", stderr); } while (0)
#define ASSERT_NULL(a) ASSERT_IS_OR_IS_NOT_NULL(a, "is", ==)
#define ASSERT_NOT_NULL(a) ASSERT_IS_OR_IS_NOT_NULL(a, "is not", !=)

#define SET_FP(value, e_value, s_value) do { \
    value.e = (e_value); \
    value.s = (s_value); \
} while (0)

#define ASSERT_FP_EQ(value, e_value, s_value) do { \
    ASSERT_EQ(value.e, e_value); \
    ASSERT_EQ(value.s, s_value); \
} while (0)

#define DEBUG(x) fprintf(stderr, #x "=%d\n", (x))

#endif
