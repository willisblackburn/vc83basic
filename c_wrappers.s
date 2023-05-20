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

.export _reg_bc = BC
.export _reg_b = B
.export _reg_c = C
.export _reg_de = DE
.export _reg_d = D
.export _reg_e = E

.export _FP0 = FP0
.export _FP0t = FP0t
.export _FP0e = FP0e
.export _FP0s = FP0s
.export _FP1 = FP1
.export _FP1t = FP1t
.export _FP1e = FP1e
.export _FP1s = FP1s
.export _FP2 = FP2

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

_carry_flag: .res 1
.export _carry_flag

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

; Sets the carry_flag variable to 1 if carry is set, 0 otherwise.
set_carry_flag:
        pha                             ; Save return value
        lda     #0                      ; Roll carry left into A and save in carry_flag
        rol     A
        sta     _carry_flag
        pla                             ; Restore return value
        rts

; Returns 0 or 1 based on the zero flag state.
return_zero_flag:
        beq     @zero
        jmp     return0
@zero:
        jmp     return1

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
        jmp     set_carry_flag

_push_fp0:
.export _push_fp0
        jsr     push_fp0
        jmp     set_carry_flag

_pop_fp0:
.export _pop_fp0
        jmp     pop_fp0

_stack_alloc:
.export _stack_alloc
        jsr     stack_alloc
        jmp     set_carry_flag

_stack_free:
.export _stack_free
        jmp     stack_free

; fp.s

_load_fpx:
.export _load_fpx
        stax    BC                      ; value pointer
        jsr     popax                   ; fpx pointer
        tax
        lday    BC
        jmp     load_fpx

_store_fpx:
.export _store_fpx
        stax    BC                      ; value pointer
        jsr     popax                   ; fpx pointer
        tax
        lday    BC
        jmp     store_fpx

_swap_fp0_fp1:
.export _swap_fp0_fp1
        jmp     swap_fp0_fp1

_int_to_fp:
.export _int_to_fp
        jmp     int_to_fp

_int32_to_fp:
.export _int32_to_fp
        jmp     int32_to_fp

_truncate_fp_to_int:
.export _truncate_fp_to_int
        jsr     truncate_fp_to_int
        jmp     set_carry_flag

_truncate_fp_to_int32:
.export _truncate_fp_to_int32
        jsr     truncate_fp_to_int32
        jmp     set_carry_flag

_char_to_digit:
.export _char_to_digit
        jsr     char_to_digit
        jmp     set_carry_flag

_adjust_exponent:
.export _adjust_exponent
        pha                             ; popa uses Y so can't move it immediately
        jsr     popa
        tax                             ; Add byte
        pla
        tay                             ; Subtract byte
        jmp     adjust_exponent

_fp_to_string:
.export _fp_to_string
        jmp     fp_to_string

_string_to_fp:
.export _string_to_fp
        jsr     string_to_fp
        jmp     set_carry_flag

_normalize:
.export _normalize
        jsr     normalize
        jmp     set_carry_flag

_fadd:
.export _fadd
        jsr     fadd
        jmp     set_carry_flag

_fsub:
.export _fsub
        jsr     fsub
        jmp     set_carry_flag

_fmul:
.export _fmul
        jsr     fmul
        jmp     set_carry_flag

_fdiv:
.export _fdiv
        jsr     fdiv
        jmp     set_carry_flag

_fneg:
.export _fneg
        jmp     fneg

; Possible returns from fcmp are:
; C + Z         -> A = B
; C + NOT Z     -> A > B
; NOT C + Z     -> (not possible)
; NOT C + NOT Z -> A < B

_fcmp:
.export _fcmp
        jsr     fcmp
        bcc     @less                   ; Carry cleawr means borrow so A < B
        beq     @equal
        ldax    #1
        rts

@equal:
        ldax    #0
        rts

@less:
        ldax    #-1
        rts

; list.s

_list_line:
.export _list_line
        jsr     list_line
        jmp     set_carry_flag

_list_statement:
.export _list_statement
        jmp     list_statement

_list_directive:
.export _list_directive
        jmp     list_directive

; name.s

_find_name:
.export _find_name
        jsr     find_name
        jmp     set_carry_flag

_get_name_table_entry:
.export _get_name_table_entry
        sta     B                       ; Index arrives in A; we need it in Y
        jsr     popax                   ; Name table pointer
        ldy     B                       ; Load index into Y
        jsr     get_name_table_entry
        jmp     set_carry_flag

_add_variable:
.export _add_variable
        jsr     add_variable
        jmp     set_carry_flag

; parser.s

_parse_line:
.export _parse_line
        jsr     parse_line
        jmp     set_carry_flag

_parse_statement:
.export _parse_statement
        jsr     parse_statement
        jmp     set_carry_flag

_parse_directive:
.export _parse_directive
        sta     lp
        jsr     popa
        sta     bp
        jsr     popa
        jsr     parse_directive
        jmp     set_carry_flag

_parse_expression:
.export _parse_expression
        sta     lp
        jsr     popa
        sta     bp
        jsr     parse_expression
        jmp     set_carry_flag

_parse_argument_separator:
.export _parse_argument_separator
        sta     bp
        jsr     parse_argument_separator
        jmp     set_carry_flag

_parse_name:
.export _parse_name
        jsr     parse_name
        jmp     set_carry_flag

_is_name_character:
.export _is_name_character
        jsr     is_name_character
        jmp     set_carry_flag

_parse_operator_name:
.export _parse_operator_name
        jsr     parse_operator_name
        jmp     set_carry_flag

_is_operator_name_character:
.export _is_operator_name_character
        sta     B                       ; Index arrives in A; we need it in Y
        jsr     popa                    ; Character to test
        ldy     B                       ; Recover index from B
        jsr     is_operator_name_character
        jmp     set_carry_flag

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

_find_line_ax:
.export _find_line_ax
        jsr     find_line_ax
        jmp     return_carry_flag

_advance_next_line_ptr:
.export _advance_next_line_ptr
        jmp     advance_next_line_ptr

_insert_or_update_line:
.export _insert_or_update_line
        jsr     insert_or_update_line
        jmp     return_carry_flag

_grow:
.export _grow
        stax    BC                      ; Save size temporarily
        jsr     popax                   ; Get ptr (ignore high byte in X)
        tay                             ; Store in Y
        ldax    BC                      ; Get the size again
        jsr     grow
        jmp     return_carry_flag

_shrink:
.export _shrink
        stax    BC                      ; Save size temporarily
        jsr     popax                   ; Get ptr (ignore high byte in X)
        tay                             ; Store in Y
        ldax    BC                      ; Get the size again
        jsr     shrink
        jmp     return_carry_flag
        rts

_calculate_bytes_to_move:
.export _calculate_bytes_to_move
        jmp     calculate_bytes_to_move

_check_himem:
.export _check_himem
        jsr     check_himem
        jmp     return_carry_flag

_set_variable_value_ptr:
.export _set_variable_value_ptr
        jmp     set_variable_value_ptr

_mul_value_size:
.export _mul_value_size
        jmp     mul_value_size

; util.s

_copy_down_ax:
.export _copy_down_ax
        stax    DE                      ; Size
        jsr     popax
        stax    src_ptr
        jsr     popax
        stax    dst_ptr
        ldax    DE
        jmp     copy_down_ax

_copy_up_ax:
.export _copy_up_ax
        stax    DE
        jsr     popax
        stax    src_ptr
        jsr     popax
        stax    dst_ptr
        ldax    DE
        jmp     copy_up_ax

_invoke_indexed_vector:
.export _invoke_indexed_vector
        sta     B                       ; Index arrives in A; we need it in Y
        jsr     popax                   ; Address of vector array
        ldy     B      
        jmp     invoke_indexed_vector
