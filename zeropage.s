.include "basic.inc"

; Zero page data

.zeropage

; Additional general-purpose "registers." Register rules apply; don't expect them to be preserved unless a
; function declares B SAFE etc. Can be used as the 16-bit pairs BC and DE. Don't alias these.

BC:
B: .res 1
C: .res 1
DE:
D: .res 1
E: .res 1

FP0: .res .sizeof(UnpackedFloat)
FP0t = FP0+UnpackedFloat::t
FP0e = FP0+UnpackedFloat::e
FP0s = FP0+UnpackedFloat::s
FP1: .res .sizeof(UnpackedFloat)
FP1t = FP1+UnpackedFloat::t
FP1e = FP1+UnpackedFloat::e
FP1s = FP1+UnpackedFloat::s
FP2: .res .sizeof(UnpackedFloat::t)
FP3: .res .sizeof(UnpackedFloat::t)

fp_temp: .res .sizeof(Float)

; Source and destination pointers for memory opreations
src_ptr: .res 2
dst_ptr: .res 2

; Size for memory operations
size: .res 2

; Pointer to the table of vectors used by invoke_indexed_vector
vector_table_ptr: .res 2

; A pointer to the start of the program
program_ptr: .res 2

; A pointer to the current program line
line_ptr: .res 2

; The value that line_ptr should take after we finish executing the current line.
; May be modified by control statements like GOTO, GOSUB, RETURN, NEXT, etc.
next_line_ptr: .res 2

; The start of the variable name table
variable_name_table_ptr: .res 2

; The start of the variable value table; maintained as the end of the variable name table
value_table_ptr: .res 2

; The start of the free space beyond the heap
free_ptr: .res 2

; The address of "high memory" that will not be touched by the interpreter
himem_ptr: .res 2

; Read/write position in buffer
bp: .res 1

; The starting position of the name
name_bp: .res 1

; The number of arguments that parse_argument_list is parsing
argument_count: .res 1

; Read/write position in line
lp: .res 1

; The next value of lp (analogous to next_line_ptr)
next_lp: .res 1

; Position of current statement
statement_lp: .res 1

; The line number sought by find_line
line_number: .res 2

; The number of variables in the program
variable_count: .res 1

; Pointer to the variable value set by a statement like LET, INPUT, and READ
variable_value_ptr: .res 2

; Pointer to current name table entry
name_ptr: .res 2

; Read position in the name table entry
np: .res 1

; Index of matched name
matched_name_index: .res 1

; Whether the program is not running, running, stopped, or awaiting reset.
program_state: .res 1

; The vector table pointer that was passed into decode_expression
decode_expression_vector_table_ptr: .res 2

; Op stack position; points to last-used position and initialized to OP_STACK_SIZE
osp: .res 1

; Primary stack position; same behavior as osp but initialized to PRIMARY_STACK_SIZE
psp: .res 1

; Minimum operator precedence used in process_operators
min_precedence: .res 1

; The number we're dispatching in an ON...GOTO/GOSUB statement
on_value: .res 1

; The handler vector for ON...GOTO/GOSUB
on_handler: .res 2

; Where to resume execution after STOP
resume_line_ptr: .res 2

; Position of resume statement
resume_lp: .res 1

.bss
