.include "basic.inc"

; Zeropage and BSS data

.zeropage

; Additional general-purpose "registers." Register rules apply; don't expect them to be preserved unless a
; function declares B SAFE etc. Can be used as the 16-bit pairs BC and DE. Don't alias these.

BC:
B: .res 1
C: .res 1
DE:
D: .res 1
E: .res 1

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

.bss
