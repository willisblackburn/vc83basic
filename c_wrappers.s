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

.export _statement_name_table = statement_name_table

.export _line_ptr = line_ptr
.export _program_ptr = program_ptr
.export _variable_name_table_ptr = variable_name_table_ptr
.export _value_table_ptr = value_table_ptr
.export _heap_ptr = heap_ptr
.export _himem_ptr = himem_ptr
.export _variable_count = variable_count
.export _variable_value_ptr = variable_value_ptr

.export _status = status

.export _r = r
.export _w = w

.export _name_ptr = name_ptr

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

; decode.s

_decode_number:
.export _decode_number
        sta     r
        jsr     popax
        stax    line_ptr
        jmp     decode_number

_decode_byte:
.export _decode_byte
        sta     r
        jsr     popax
        stax    line_ptr
        jmp     decode_byte

; encode.s

_encode_number:
.export _encode_number
        sta     w
        jsr     popax
        jsr     encode_number
        jmp     return_carry

_encode_byte:
.export _encode_byte
        sta     w
        jsr     popa
        jsr     encode_byte
        jmp     return_carry

; name.s

_is_name_character:
.export _is_name_character
        jsr     is_name_character
        jmp     return_carry

_find_name:
.export _find_name
        sta     r                       ; Buffer index
        jsr     popax                   ; Name table pointer
        jsr     find_name
        jmp     return_carry

_match_character_sequence:
.export _match_character_sequence
        sta     r
        jsr     popa
        sta     B      
        jsr     popax
        stax    name_ptr
        ldy     B      
        jsr     match_character_sequence
        jmp     return_carry

_get_name_table_entry:
.export _get_name_table_entry
        sta     B                       ; Index arrives in A; we need it in Y
        jsr     popax                   ; Name table pointer
        ldy     B                       ; Load index into Y
        jsr     get_name_table_entry
        jmp     return_carry

_add_variable:
.export _add_variable
        jsr     add_variable
        jmp     return_carry

; parser.s

_read_number:
.export _read_number
        sta     r                       ; Buffer index
        jsr     read_number
        jmp     return_carry

_char_to_digit:
.export _char_to_digit
        jsr     char_to_digit
        jmp     return_carry

_parse_element:
.export _parse_element
        sta     w
        jsr     popa
        sta     r
        jsr     popax                   ; Name table pointer
        stax    name_ptr
        jsr     parse_element
        jmp     return_carry

_parse_repeated_argument:
.export _parse_repeated_argument
        sta     w
        jsr     popa
        sta     r
        jsr     popa
        jsr     parse_repeated_argument
        jmp     return_carry

_parse_argument:
.export _parse_argument
        sta     w
        jsr     popa
        sta     r
        jsr     popa
        jsr     parse_argument
        jmp     return_carry

_parse_expression:
.export _parse_expression
        sta     w
        jsr     popa
        sta     r
        jsr     parse_expression
        jmp     return_carry

_parse_argument_separator:
.export _parse_argument_separator
        sta     r
        jsr     parse_argument_separator
        jmp     return_carry

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
        jsr     insert_or_update_line
        jmp     return_carry

_grow_variable_name_table:
.export _grow_variable_name_table
        jsr     grow_variable_name_table
        jmp     return_carry

_check_himem:
.export _check_himem
        sta     B                       ; Swap A and X
        txa                     
        ldx     B      
        jsr     check_himem
        jmp     return_carry

_set_variable_value_ptr:
.export _set_variable_value_ptr
        jmp     set_variable_value_ptr

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

_copy_bytes_back:
.export _copy_bytes_back
        stax    DE
        jsr     popax
        stax    src_ptr
        jsr     popax
        stax    dst_ptr
        ldax    DE
        jmp     copy_bytes_back

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
        sta     w
        jsr     popax
        jmp     format_number
