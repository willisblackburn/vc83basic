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
    unsigned long t;
    char e;
} Float;

typedef struct UnpackedFloat {
    unsigned long t;
    char e;
    char s;
} UnpackedFloat;

// Zero Page

extern int reg_bc;
#pragma zpsym ("reg_bc")
extern char reg_b;
#pragma zpsym ("reg_b")
extern char reg_c;
#pragma zpsym ("reg_c")
extern int reg_de;
#pragma zpsym ("reg_de")
extern char reg_d;
#pragma zpsym ("reg_d")
extern char reg_e;
#pragma zpsym ("reg_e")
extern UnpackedFloat FP0;
#pragma zpsym ("FP0")
extern unsigned long FP0t;
#pragma zpsym ("FP0t")
extern char FP0e;
#pragma zpsym ("FP0e")
extern char FP0s;
#pragma zpsym ("FP0s")
extern UnpackedFloat FP1;
#pragma zpsym ("FP1")
extern unsigned long FP1t;
#pragma zpsym ("FP1t")
extern char FP1e;
#pragma zpsym ("FP1e")
extern char FP1s;
#pragma zpsym ("FP1s")
extern unsigned long FP2;
#pragma zpsym ("FP2")
extern unsigned long FP3;
#pragma zpsym ("FP3")
extern char bp;
#pragma zpsym ("bp")
extern char name_bp;
#pragma zpsym ("name_bp")
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

extern char carry_flag;

// Prototypes for C wrapper functions

// decode.s
void decode_expression(void** vector_table_ptr);
int decode_number(void);
char decode_variable(void);
char decode_operator(void);
char decode_unary_operator(void);
char decode_byte(void);

// expression.h
char evaluate_expression(void);
char push_value(int value);
int pop_value(void);
char stack_alloc(char size);
void stack_free(char size);

// encode.s
int encode_number(int number);
int encode_byte(char value);

// fp.s
void load_fpx(UnpackedFloat* fpx, const Float* value);
void store_fpx(const UnpackedFloat* fpx, Float* value);
void swap_fp0_fp1(void);
void int_to_fp(int value);
void int32_to_fp(void);
char truncate_fp_to_int(void);
int truncate_fp_to_int32(void);
void fp_to_string(void);
char string_to_fp(void);
char char_to_digit(char c);
void adjust_exponent(char add, char subtract);
char normalize(void);
char fadd(void);
char fsub(void);
char fmul(void);
char fdiv(void);
void fneg(void);
int fcmp(void);

// list.s
char list_line(void);
void list_statement(void);
void list_directive(char directive);

// name.s
int find_name(const char* name_ptr);
int get_name_table_entry(const char* name_ptr, char index);
int add_variable(void);

// parser.s
int read_number(char bp);
int parse_line(void);
char parse_statement(const char* name_ptr);
int parse_directive(char directive, char bp, char lp);
int parse_expression(char bp, char lp);
int parse_argument_separator(char bp);
int parse_name(void);
int is_name_character(char c);
int parse_operator_name();
int is_operator_name_character(char c, char index);

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
int mul2(int value);
int mul10(int value);
int div10(int value);
int invoke_indexed_vector(void* vectors, char index);
void format_number(int number, char bp);

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

void set_line(int line, const char* data, size_t length) {
    line_buffer.number = line;
    line_buffer.next_line_offset = (char)(length + offsetof(Line, data));
    memcpy(line_buffer.data, data, length);
    line_ptr = &line_buffer;
    lp = (char)offsetof(Line, data);
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
