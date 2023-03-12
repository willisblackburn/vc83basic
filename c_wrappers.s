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

.export _bp = bp
.export _src_ptr = src_ptr
.export _dst_ptr = dst_ptr
.export _buffer = buffer
.export _line_buffer = line_buffer

.export _program_ptr = program_ptr
.export _line_ptr = line_ptr
.export _free_ptr = free_ptr
.export _himem_ptr = himem_ptr

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
return_carry_flag:
        stax    _reg_ax
        sty     _reg_y
        lda     #0
        tax
        rol     A
        rts

; Function wrappers

; parser.s

_read_number:
.export _read_number
        sta     bp               
        jsr     read_number
        jmp     return_carry_flag

_char_to_digit:
.export _char_to_digit
        jsr     char_to_digit
        jmp     return_carry_flag

_parse_keyword:
.export _parse_keyword
        sta     bp              
        jsr     popax                   ; Keyword pointer
        jsr     parse_keyword
        jmp     return_carry_flag

; program.s

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
        jmp     return_carry_flag

_advance_line_ptr:
.export _advance_line_ptr
        jmp     advance_line_ptr

_insert_or_update_line:
.export _insert_or_update_line
        jsr     insert_or_update_line
        jmp     return_carry_flag

_expand:
.export _expand
        stax    BC                      ; Save size temporarily
        jsr     popax                   ; Get ptr (ignore high byte in X)
        tay                             ; Store in Y
        ldax    BC                      ; Get the size again
        jsr     expand
        jmp     return_carry_flag

_compact:
.export _compact
        stax    BC                      ; Save size temporarily
        jsr     popax                   ; Get ptr (ignore high byte in X)
        tay                             ; Store in Y
        ldax    BC                      ; Get the size again
        jsr     compact
        jmp     return_carry_flag
        rts

_calculate_bytes_to_move:
.export _calculate_bytes_to_move
        jsr     calculate_bytes_to_move
        ldax    DE                      ; Function returns in DE; copy to AX for convenience
        rts

_check_himem:
.export _check_himem
        jsr     check_himem
        jmp     return_carry_flag

; util.s

_copy_bytes:
.export _copy_bytes
        stax    DE                      ; Size
        jsr     popax
        stax    src_ptr
        jsr     popax
        stax    dst_ptr
        ldax    DE
        jmp     copy_bytes

_copy_bytes_higher:
.export _copy_bytes_higher
        stax    DE
        jsr     popax
        stax    src_ptr
        jsr     popax
        stax    dst_ptr
        ldax    DE
        jmp     copy_bytes_higher

_mul10:
.export _mul10
        jmp     mul10

_div10:
.export _div10
        jsr     div10
        sty     _reg_y                  ; Save remainder
        rts
