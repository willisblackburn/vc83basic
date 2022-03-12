; Wrappers around assembly language functions to make them callable from C.
; The assembly language functions don't use the C stack, so the wrapper functions
; pop arguments from the C stack and put them in the right places before calling
; the assembly function.
; C prototypes are in test.h.

; cc65 runtime
.include "zeropage.inc"
.import popax, popptr1, incsp2, return0, return1

.include "target.inc"
.include "basic.inc"

; Aliases for globals

.export _buffer = buffer
.export _buffer_length = buffer_length

.export _output_buffer = output_buffer
.export _output_buffer_length = output_buffer_length

.export _line_ptr = line_ptr
.export _program_start = program_start
.export _program_end = program_end

.export _status = status

.export _r = r
.export _w = w;

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

; Pops a word from C stack into zero-page register identified by X.

popzpword:
        ldy     #0
        lda     (sp),y
        sta     0,x
        iny           
        inx
        lda     (sp),y
        sta     0,x
        jmp     incsp2

; Returns 0 or 1 depending on the carry state,
; and sets _ax to whatever the function returned in AX.
return_carry:
        sta     _reg_a
        stx     _reg_x
        sty     _reg_y
        lda     #0
        tax
        rol     A
        rts

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

; parser.s

_parse_number:
.export _parse_number
        sta     r               ; Buffer index
        jsr     parse_number
        jmp     return_carry

_char_to_digit:
.export _char_to_digit
        jsr     char_to_digit
        jmp     return_carry

_find_name:
.export _find_name
        sta     r               ; Buffer index
        jsr     popax           ; Name table pointer
        jsr     find_name
        jmp     return_carry

; encode.s

_encode_int:
.export _encode_int
        jsr     encode_int
        jmp     return_carry

; util.s

_copy_bytes:
.export _copy_bytes
        sta     copy_length
        stx     copy_length+1
        ldx     #copy_from
        jsr     popzpword
        ldx     #copy_to
        jsr     popzpword
        jmp     copy_bytes

_copy_bytes_back:
.export _copy_bytes_back
        sta     copy_length
        stx     copy_length+1
        ldx     #copy_from
        jsr     popzpword
        ldx     #copy_to
        jsr     popzpword
        jmp     copy_bytes_back

_mul10:
.export _mul10
        jmp     mul10

_div10:
.export _div10
        jsr     div10
        sty     _reg_y          ; Save remainder
        rts
