ifelse(
    OUTPUT, `s', `
.zeropage
define(`var', ``$1: .res $2
.export _$1 = $1'')
define(`comment', `;')
define(`block', ``$1 = *
.assert $1_END - $1 = $2, error'')
define(`endblock', ``$1_END = *'')
define(`finalize', `.code')
    ',
    OUTPUT, `inc', `
define(`var', ``.globalzp $1'')
define(`comment', `;')
define(`block', ``.globalzp $1
$1_SIZE = $2'')
define(`endblock', `')
define(`finalize', `')
    ',
    OUTPUT, `h', `
define(`var', ``extern $3 $1;
#pragma zpsym("$1")'')
define(`comment', `//')
define(`block', `')
define(`endblock', `')
define(`finalize', `')
    ')

define(`byte', `var($1, 1, ifelse($2, `', `char', $2))')
define(`word', `var($1, 2, ifelse($2, `', `int', $2))')

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

comment The start of the variable name table
word(variable_name_table_ptr, char*)

comment The start of free space past the variable name table
word(free_ptr, void*)

comment The address of "high memory" that will not be touched by the interpreter
word(himem_ptr, void*)

comment The line number sought by find_line
word(line_number)

comment NAME_STATE is the set of zero page values that parse_statement restores after parsing a directive
block(NAME_STATE, 5)

comment Pointer to current name table entry
word(name_ptr, char*)

comment Pointer to the next name table entry
word(next_name_ptr, const char*)

comment Index of name in name table
byte(name_index)

endblock(NAME_STATE)

comment Read/write position in buffer
byte(buffer_pos)

comment Read/write position in line
byte(line_pos)

comment DECODE_NAME_STATE is the set of zero page fields that describe a name decoded from a program line
block(DECODE_NAME_STATE, 3)

comment Pointer to name decoded from line
word(decode_name_ptr, const char*)

comment Length of the name referred to by decode_name_ptr
byte(decode_name_length)

endblock(DECODE_NAME_STATE)

comment Whether the program is not running, running, stopped, or awaiting reset
byte(program_state)

comment Pointer to the source of data when reading a value
word(read_ptr, const char*)

comment The vector table pointer that was passed into decode_expression
word(decode_expression_vector_table_ptr, void*)

comment Op stack position; points to last-used position and initialized to OP_STACK_SIZE
byte(op_stack_pos)

comment Primary stack position; same behavior as op_stack_pos but initialized to PRIMARY_STACK_SIZE
byte(stack_pos)

comment Minimum operator precedence used in process_operators
byte(min_precedence)

finalize()
