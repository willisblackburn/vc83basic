; Wrappers around assembly language functions to make them callable from C.
; The assembly language functions don't use the C stack, so the wrapper functions
; pop arguments from the C stack and put them in the right places before calling
; the assembly function.
; C prototypes are in test.h.

; cc65 runtime
.import popa, popax, return0, return1

.include "../macros.inc"
.include "../basic.inc"

; Aliases for globals

.export _bp = bp
.export _name_bp = name_bp
.export _lp = lp
.export _src_ptr = src_ptr
.export _dst_ptr = dst_ptr
.export _size = size
.export _vector_table_ptr = vector_table_ptr
.export _buffer = buffer
.export _line_buffer = line_buffer

.export _statement_name_table = statement_name_table

.export _program_ptr = program_ptr
.export _line_ptr = line_ptr
.export _variable_name_table_ptr = variable_name_table_ptr
.export _value_table_ptr = value_table_ptr
.export _free_ptr = free_ptr
.export _himem_ptr = himem_ptr
.export _variable_count = variable_count
.export _variable_value_ptr = variable_value_ptr

.export _name_ptr = name_ptr
.export _np = np

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

; decode.s

_decode_number:
.export _decode_number
        jmp     decode_number

_decode_byte:
.export _decode_byte
        jmp     decode_byte

; encode.s

_encode_number:
.export _encode_number
        jsr     encode_number
        jmp     set_err

_encode_byte:
.export _encode_byte
        jsr     encode_byte
        jmp     set_err

; name.s

_find_name:
.export _find_name
        jsr     find_name
        jmp     set_err

_get_name_table_entry:
.export _get_name_table_entry
        sta     B                       ; Index arrives in A; we need it in Y
        jsr     popax                   ; Name table pointer
        ldy     B                       ; Load index into Y
        jsr     get_name_table_entry
        jmp     set_err

_add_variable:
.export _add_variable
        jsr     add_variable
        jmp     set_err

; parser.s

_read_number:
.export _read_number
        sta     bp                      ; Buffer index
        jsr     read_number
        jmp     set_err

_char_to_digit:
.export _char_to_digit
        jsr     char_to_digit
        jmp     set_err

_parse_line:
.export _parse_line
        jsr     parse_line
        jmp     set_err

_parse_statement:
.export _parse_statement
        jsr     parse_statement
        jmp     set_err

_parse_directive:
.export _parse_directive
        jsr     parse_directive
        jmp     set_err

_parse_expression:
.export _parse_expression
        jsr     parse_expression
        jmp     set_err

_parse_argument_separator:
.export _parse_argument_separator
        jsr     parse_argument_separator
        jmp     set_err

_parse_name:
.export _parse_name
        jsr     parse_name
        jmp     set_err

_is_name_character:
.export _is_name_character
        jsr     is_name_character
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

_calculate_bytes_to_move:
.export _calculate_bytes_to_move
        jmp     calculate_bytes_to_move

_check_himem:
.export _check_himem
        jsr     check_himem
        jmp     set_err

_set_variable_value_ptr:
.export _set_variable_value_ptr
        jmp     set_variable_value_ptr

; util.s

_copy:
.export _copy
        stax    DE                      ; Size
        jsr     popax
        stax    src_ptr
        jsr     popax
        stax    dst_ptr
        ldax    DE
        jmp     copy

_reverse_copy:
.export _reverse_copy
        stax    DE
        jsr     popax
        stax    src_ptr
        jsr     popax
        stax    dst_ptr
        ldax    DE
        jmp     reverse_copy

_clear_memory:
.export _clear_memory
        stax    DE                      ; Size
        jsr     popax
        stax    dst_ptr                 ; Get the pointer into BC
        ldax    DE                      ; Restore size into AX
        jmp     clear_memory

_mul2:
.export _mul2
        jmp     mul2

_mul10:
.export _mul10
        jmp     mul10

_div10:
.export _div10
        jsr     div10
        sty     _reg_y                  ; Save remainder
        rts

_invoke_indexed_vector:
.export _invoke_indexed_vector
        sta     B                       ; Index arrives in A; we need it in Y
        jsr     popax                   ; Address of vector array
        ldy     B      
        jmp     invoke_indexed_vector

_format_number:
.export _format_number
        sta     bp
        jsr     popax
        jmp     format_number
