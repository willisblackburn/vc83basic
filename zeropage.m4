ifelse(
    OUTPUT, `s', `
.include "basic.inc"
.zeropage
define(`var', ``$1: .res $2
.export _$1 = $1'') define(`comment', `;')
    ',
    OUTPUT, `inc', `
define(`var', ``.globalzp $1'') define(`comment', `;')
    ',
    OUTPUT, `h', `
define(`var', ``extern $3 $1;
#pragma zpsym("$1")'') define(`comment', `//')
    ')

define(`byte', `var($1, 1, char)')
define(`word', `var($1, 2, $2)')

comment Generated from __file__

comment Additional general-purpose "registers." Register rules apply; don't expect them to be preserved unless a
comment function declares B SAFE etc. Can be used as the 16-bit pairs BC and DE. Don't alias these.

byte(B)
byte(C)
byte(D)
byte(E)

comment Source and destination pointers for memory opreations
word(src_ptr, void*)
word(dst_ptr, void*)

comment Size for memory operations
word(size, size_t)

comment Pointer to the table of vectors used by invoke_indexed_vector
word(vector_table_ptr, void**)

comment A pointer to the start of the program
word(program_ptr, Line*)

comment A pointer to the current program line
word(line_ptr, Line*)

comment The value that line_ptr should take after we finish executing the current line.
comment May be modified by control statements like GOTO, GOSUB, RETURN, NEXT, etc.
word(next_line_ptr, Line*)

comment The start of the variable name table
word(variable_name_table_ptr, char*)

comment The start of free space past the variable name table
word(free_ptr, void*)

comment The address of "high memory" that will not be touched by the interpreter
word(himem_ptr, void*)

comment Read/write position in buffer
byte(buffer_pos)

comment The number of arguments that parse_argument_list is parsing
byte(argument_count)

comment Read/write position in line
byte(line_pos)

comment The line number sought by find_line
word(line_number, int)

comment Pointer to current name table entry
word(name_ptr, char*)

comment Pointer to the next name table entry
word(next_name_ptr, char*)

comment Index of name in name table
byte(name_index)

comment Pointer to name decoded from line
word(decode_name_ptr, const char*)

comment Length of the name referred to by decode_name_ptr
byte(decode_name_length)

comment The type of the name referred to by decode_name_ptr
byte(decode_name_type)

comment Pointer to a variable within the variable value set by a statement like LET, INPUT, and READ
word(variable_ptr, void*)

comment Whether the program is not running, running, stopped, or awaiting reset.
byte(program_state)
