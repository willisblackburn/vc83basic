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
.export _name_bp = name_bp
.export _lp = lp
.export _src_ptr = src_ptr
.export _dst_ptr = dst_ptr
.export _vector_table_ptr = vector_table_ptr
.export _buffer = buffer
.export _line_buffer = line_buffer

.export _statement_name_table = statement_name_table

.export _program_ptr = program_ptr
.export _line_ptr = line_ptr
.export _next_line_ptr = next_line_ptr
.export _variable_name_table_ptr = variable_name_table_ptr
.export _value_table_ptr = value_table_ptr
.export _free_ptr = free_ptr
.export _himem_ptr = himem_ptr
.export _variable_count = variable_count
.export _variable_value_ptr = variable_value_ptr

.export _name_ptr = name_ptr
.export _np = np

.export _osp = osp
.export _psp = psp

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

; decode.s

_decode_expression:
.export _decode_expression
        jmp     decode_expression

_decode_number:
.export _decode_number
        jmp     decode_number

_decode_variable:
.export _decode_variable
        jmp     decode_variable

_decode_operator:
.export _decode_operator
        jmp     decode_operator

_decode_unary_operator:
.export _decode_unary_operator
        jmp     decode_unary_operator

_decode_byte:
.export _decode_byte
        jmp     decode_byte

; encode.s

_encode_number:
.export _encode_number
        jsr     encode_number
        jmp     return_carry_flag

_encode_byte:
.export _encode_byte
        jsr     encode_byte
        jmp     return_carry_flag

; expression.s

_evaluate_expression:
.export _evaluate_expression
        jsr     evaluate_expression
        jmp     return_carry_flag

_push_value:
.export _push_value
        jsr     push_value
        jmp     return_carry_flag

_pop_value:
.export _pop_value
        jmp     pop_value

_stack_alloc:
.export _stack_alloc
        jsr     stack_alloc
        jmp     return_carry_flag

_stack_free:
.export _stack_free
        jmp     stack_free

; list.s

_list_line:
.export _list_line
        jsr     list_line
        jmp     return_carry_flag

_list_element:
.export _list_element
        sta     bp
        jsr     popa
        sta     lp
        jsr     popax
        stax    line_ptr
        jsr     popa
        sta     B                       ; Store index temporarily in B
        jsr     popax
        ldy     B                       ; Move index back into B
        jmp     list_element

_list_directive:
.export _list_directive
        sta     bp
        jsr     popa
        sta     lp
        jsr     popax
        stax    line_ptr
        jsr     popa
        jmp     list_directive

; name.s

_find_name:
.export _find_name
        jsr     find_name
        jmp     return_carry_flag

_get_name_table_entry:
.export _get_name_table_entry
        sta     B                       ; Index arrives in A; we need it in Y
        jsr     popax                   ; Name table pointer
        ldy     B                       ; Load index into Y
        jsr     get_name_table_entry
        jmp     return_carry_flag

_add_variable:
.export _add_variable
        jsr     add_variable
        jmp     return_carry_flag

; parser.s

_read_number:
.export _read_number
        sta     bp                      ; Buffer index
        jsr     read_number
        jmp     return_carry_flag

_char_to_digit:
.export _char_to_digit
        jsr     char_to_digit
        jmp     return_carry_flag

_parse_line:
.export _parse_line
        jsr     parse_line
        jmp     return_carry_flag

_parse_statement:
.export _parse_statement
        jsr     parse_statement
        jmp     return_carry_flag

_parse_directive:
.export _parse_directive
        sta     lp
        jsr     popa
        sta     bp
        jsr     popa
        jsr     parse_directive
        jmp     return_carry_flag

_parse_expression:
.export _parse_expression
        sta     lp
        jsr     popa
        sta     bp
        jsr     parse_expression
        jmp     return_carry_flag

_parse_argument_separator:
.export _parse_argument_separator
        sta     bp
        jsr     parse_argument_separator
        jmp     return_carry_flag

_parse_name:
.export _parse_name
        jsr     parse_name
        jmp     return_carry_flag

_is_name_character:
.export _is_name_character
        jsr     is_name_character
        jmp     return_carry_flag

_parse_operator_name:
.export _parse_operator_name
        jsr     parse_operator_name
        jmp     return_carry_flag

_is_operator_name_character:
.export _is_operator_name_character
        sta     B                       ; Index arrives in A; we need it in Y
        jsr     popa                    ; Character to test
        ldy     B                       ; Recover index from B
        jsr     is_operator_name_character
        jmp     return_carry_flag

; program.s

_initialize_target:
.export _initialize_target
        jmp     initialize_target

_initialize_program:
.export _initialize_program
        jmp     initialize_program

_reset_next_line_ptr:
.export _reset_next_line_ptr
        jmp     reset_next_line_ptr

_find_line:
.export _find_line
        jsr     find_line
        jmp     return_carry_flag

_advance_next_line_ptr:
.export _advance_next_line_ptr
        jmp     advance_next_line_ptr

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

_copy_bytes_higher:
.export _copy_bytes_higher
        stax    DE
        jsr     popax
        stax    src_ptr
        jsr     popax
        stax    dst_ptr
        ldax    DE
        jmp     copy_bytes_higher

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
