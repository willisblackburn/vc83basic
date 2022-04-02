; Wrappers around assembly language functions to make them callable from C.
; The assembly language functions don't use the C stack, so the wrapper functions
; pop arguments from the C stack and put them in the right places before calling
; the assembly function.
; C prototypes are in test.h.

; cc65 runtime
.include "zeropage.inc"
.import popax, popptr1, incsp2, return0, return1

.include "basic.inc"

; Aliases for globals

_buffer = buffer
.export _buffer
_buffer_length = buffer_length
.export _buffer_length

_line_ptr = line_ptr
.export _line_ptr
_program_ptr = program_ptr
.export _program_ptr
_heap_ptr = heap_ptr
.export _heap_ptr

_status = status
.export _status

.bss

; The wrappers for functions that use the carry bit to flag errors return the carry to C and use these fields to
; save the register values returned from the function.

_reg_ax:
_reg_a: .res 1
_reg_x: .res 1
_reg_y: .res 1
.export _reg_ax, _reg_a, _reg_x, _reg_y

.code

; Function wrappers

; Same as popptr1 but for ptr2.
popptr2:
        ldy     #1
        lda     (sp),y
        sta     ptr2+1
        dey           
        lda     (sp),y
        sta     ptr2
        jmp     incsp2

; Returns 0 or 1 depending on the carry state,
; and sets _ax to whatever the function returned in AX.
return_carry:
        sta     _reg_a
        stx     _reg_x
        lda     #0
        tax
        rol     A
        rts

_initialize_arch:
.export _initialize_arch
        jmp     initialize_arch

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
        sta     r               ; Buffer index
        jsr     popax           ; Line number
        jsr     insert_or_update_line
        jmp     return_carry

_parse_number:
.export _parse_number
        sta     r               ; Buffer index
        jsr     parse_number
        jmp     return_carry

_char_to_digit:
.export _char_to_digit
        jsr     char_to_digit
        jmp     return_carry

_parse_keyword:
.export _parse_keyword
        sta     r               ; Buffer index
        jsr     popax           ; Keyword pointer
        jsr     parse_keyword
        jmp     return_carry

_copy_bytes:
.export _copy_bytes
        sta     copy_length
        stx     copy_length+1
        jsr     popax
        sta     copy_from_ptr
        stx     copy_from_ptr+1
        jsr     popax
        sta     copy_to_ptr
        stx     copy_to_ptr+1
        jmp     copy_bytes
        jmp     copy_bytes

_copy_bytes_back:
.export _copy_bytes_back
        sta     copy_length
        stx     copy_length+1
        jsr     popax
        sta     copy_from_ptr
        stx     copy_from_ptr+1
        jsr     popax
        sta     copy_to_ptr
        stx     copy_to_ptr+1
        jmp     copy_bytes_back

_mul10:
.export _mul10
        jmp     mul10

_div10:
.export _div10
        jsr     div10
        sty     _reg_y          ; Save remainder
        rts
