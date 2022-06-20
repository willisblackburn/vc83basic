; Wrappers around assembly language functions to make them callable from C.
; The assembly language functions don't use the C stack, so the wrapper functions
; pop arguments from the C stack and put them in the right places before calling
; the assembly function.
; C prototypes are in test.h.

; cc65 runtime
.import popa, popax, return0, return1

.include "macros.inc"
.include "basic.inc"

; Aliases for globals

.export _buffer = buffer
.export _line_buffer = line_buffer

.export _line_ptr = line_ptr
.export _program_ptr = program_ptr
.export _heap_ptr = heap_ptr

.export _status = status

.export _r = r

; Test access to the B, C, D, and E registers

.export _reg_bc = BC
.export _reg_b = B
.export _reg_c = C
.export _reg_de = DE
.export _reg_d = D
.export _reg_e = E

.bss

; The wrappers for functions that use the carry bit to flag errors return the carry and use these fields to
; save the register values returned from the function.

_reg_ax:
_reg_a: .res 1
_reg_x: .res 1
_reg_y: .res 1
.export _reg_ax, _reg_a, _reg_x, _reg_y

.code

; Returns 0 or 1 depending on the carry state,
; and sets _ax to whatever the function returned in AX.
return_carry:
        stax    _reg_ax
        sty     _reg_y
        lda     #0
        tax
        rol     A
        rts

; Function wrappers

_initialize_target:
.export _initialize_target
        jmp     initialize_target

_initialize_program:
.export _initialize_program
        jmp     initialize_program

_reset_line_ptr:
.export _reset_line_ptr
        jmp     reset_line_ptr

_find_line:
.export _find_line
        jsr     find_line
        jmp     return_carry

_advance_line_ptr:
.export _advance_line_ptr
        jmp     advance_line_ptr

_insert_or_update_line:
.export _insert_or_update_line
        jsr     insert_or_update_line
        jmp     return_carry

_read_number:
.export _read_number
        sta     r               
        jsr     read_number
        jmp     return_carry

_char_to_digit:
.export _char_to_digit
        jsr     char_to_digit
        jmp     return_carry

_parse_keyword:
.export _parse_keyword
        sta     r               
        jsr     popax                   ; Keyword pointer
        jsr     parse_keyword
        jmp     return_carry

_copy_bytes:
.export _copy_bytes
        stax    DE                      ; Size
        jsr     popax
        stax    src_ptr
        jsr     popax
        stax    dst_ptr
        ldax    DE
        jmp     copy_bytes

_copy_bytes_back:
.export _copy_bytes_back
        stax    DE
        jsr     popax
        stax    src_ptr
        jsr     popax
        stax    dst_ptr
        ldax    DE
        jmp     copy_bytes_back

_mul10:
.export _mul10
        jmp     mul10

_div10:
.export _div10
        jsr     div10
        sty     _reg_y                  ; Save remainder
        rts
