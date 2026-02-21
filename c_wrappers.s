; Wrappers around assembly language functions to make them callable from C.
; The assembly language functions don't use the C stack, so the wrapper functions
; pop arguments from the C stack and put them in the right places before calling
; the assembly function.
; C prototypes are in test.h.

; cc65 runtime
.import popa, popax, return0, return1

; Aliases for globals

.export _buffer_pos = buffer_pos
.export _src_ptr = src_ptr
.export _dst_ptr = dst_ptr
.export _size = size
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

_err: .res 1
.export _err

.code

; Sets the err variable to 1 if carry is set, 0 otherwise.
set_err:
        pha                             ; Save return value
        lda     #0                      ; Roll carry left into A and save in err
        rol     A
        sta     _err
        pla                             ; Restore return value
        rts

; Function wrappers

; parser.s

_read_number:
.export _read_number
        jsr     read_number
        jmp     set_err

_char_to_digit:
.export _char_to_digit
        jsr     char_to_digit
        jmp     set_err

_parse_keyword:
.export _parse_keyword
        jsr     parse_keyword
        jmp     set_err

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
        jmp     set_err

_advance_line_ptr:
.export _advance_line_ptr
        jmp     advance_line_ptr

_insert_or_update_line:
.export _insert_or_update_line
        jsr     insert_or_update_line
        jmp     set_err

_grow:
.export _grow
        stax    BC                      ; Save size temporarily
        jsr     popax                   ; Get ptr (ignore high byte in X)
        tay                             ; Store in Y
        ldax    BC                      ; Get the size again
        jsr     grow
        jmp     set_err

_shrink:
.export _shrink
        stax    BC                      ; Save size temporarily
        jsr     popax                   ; Get ptr (ignore high byte in X)
        tay                             ; Store in Y
        ldax    BC                      ; Get the size again
        jsr     shrink
        jmp     set_err

; util.s

_copy:
.export _copy
        jmp     copy

_reverse_copy:
.export _reverse_copy
        jmp     reverse_copy

_mul10:
.export _mul10
        jmp     mul10

_div10:
.export _div10
        jsr     div10
        sty     _reg_y                  ; Save remainder
        rts

.code
