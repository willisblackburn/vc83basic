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

// Zero Page

extern char status;
#pragma zpsym ("status")
extern char r;
#pragma zpsym ("r")
extern char w;
#pragma zpsym ("w")
extern const char* name_ptr;
#pragma zpsym ("name_ptr")
extern void* signature_ptr;
#pragma zpsym ("signature_ptr")
extern Line* line_ptr;
#pragma zpsym ("line_ptr")
extern Line* program_ptr;
#pragma zpsym ("program_ptr")
extern const char* variable_name_table_ptr;
#pragma zpsym ("variable_name_table_ptr")
extern void* value_table_ptr;
#pragma zpsym ("value_table_ptr")
extern void* heap_ptr;
#pragma zpsym ("heap_ptr")
extern void* himem_ptr;
#pragma zpsym ("himem_ptr")
extern char variable_count;
#pragma zpsym ("variable_count")
extern void* variable_value_ptr;
#pragma zpsym ("variable_value_ptr")

// Data

extern char buffer[];
extern Line line_buffer;

extern const char statement_name_table[];

// Used by c_wrappers.s

extern int reg_ax;
extern char reg_a;
extern char reg_x;
extern char reg_y;
extern int reg_bc;
extern char reg_b;
extern char reg_c;
extern int reg_de;
extern char reg_d;
extern char reg_e;

// Prototypes for C wrapper functions

// decode.s
int decode_number(const char* line_ptr, char r);
char decode_byte(const char* line_ptr, char r);

// encode.s
int encode_number(int number, char w);
int encode_byte(char byte_value, char w);

// name.s
int find_name(const char* name_ptr, char r);
int match_character_sequence(const char* name_ptr, char y, char r);
int is_name_character(char c);
int get_name_table_entry(const char* name_ptr, char index);
int add_variable(void);

// parser.s
int read_number(char r);
int char_to_digit(char c);
int parse_element(const char* name_ptr, char r, char w);
int parse_repeated_argument(char directive, char r, char w);
int parse_argument(char directive, char r, char w);
int parse_expression(char r, char w);
int parse_argument_separator(char r);

// program.s
void initialize_target(void);
void initialize_program(void);
void reset_line_ptr(void);
int find_line(int line_number);
void advance_line_ptr(void);
int insert_or_update_line(void);
int check_himem(void* ptr);
int grow_variable_name_table(char amount);
void set_variable_value_ptr(char variable);

// util.s
void copy_bytes(char* to, const char* from, size_t size);
void copy_bytes_back(char* to, const char* from, size_t size);
void clear_memory(char* p, size_t size);
int mul2(int value);
int mul10(int value);
int div10(int value);
int invoke_indexed_vector(void* vectors, char index);
void format_number(int number, char w);

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

#define ASSERT_OP(a, b, op) do { fprintf(stderr, "  %u  assert %s (%ld, $%lX) %s %s (%ld, $%lX): ", __LINE__, #a, (long)(a), (long)(a), #op, #b, (long)(b), (long)(b)); assert((a) op (b)); fputs("OK\n", stderr); } while (0)
#define ASSERT_EQ(a, b) ASSERT_OP(a, b, ==)
#define ASSERT_NE(a, b) ASSERT_OP(a, b, !=)
#define ASSERT_LT(a, b) ASSERT_OP(a, b, <)
#define ASSERT_LE(a, b) ASSERT_OP(a, b, <=)
#define ASSERT_GT(a, b) ASSERT_OP(a, b, >)
#define ASSERT_GE(a, b) ASSERT_OP(a, b, >=)
#define ASSERT_STRING_EQ(a, b)  do { fprintf(stderr, "  %u  assert \"%s\" == \"%s\": ", __LINE__, (a), (b)); assert(strcmp((a), (b)) == 0); fputs("OK\n", stderr); } while (0)
#define ASSERT_MEMORY_EQ(a, b, length)  do { fprintf(stderr, "  %u  assert %u byte(s) memory equals:\n", __LINE__, (length)); HEXDUMP(a, length); HEXDUMP(b, length); assert(memcmp((a), (b), (length)) == 0); fputs("OK\n", stderr); } while (0)
#define ASSERT_IS_OR_IS_NOT_NULL(a, s, op) do { fprintf(stderr, "  %u  assert %s (%u, $%X) %s NULL: ", __LINE__, #a, (a), (a), s); assert((a) op NULL); fputs("OK\n", stderr); } while (0)
#define ASSERT_NULL(a) ASSERT_IS_OR_IS_NOT_NULL(a, "is", ==)
#define ASSERT_NOT_NULL(a) ASSERT_IS_OR_IS_NOT_NULL(a, "is not", !=)

#endif
