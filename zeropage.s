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

; Source and destination pointers for memory opreations
src_ptr: .res 2
dst_ptr: .res 2

; Size for memory operations
size: .res 2

; A pointer to the start of the program
program_ptr: .res 2

; A pointer to the current program line
line_ptr: .res 2

; The start of the free space beyond the heap
free_ptr: .res 2

; The address of "high memory" that will not be touched by the interpreter
himem_ptr: .res 2

; Read/write position in buffer
buffer_pos: .res 1

; The line number sought by find_line
line_number: .res 2

.code
