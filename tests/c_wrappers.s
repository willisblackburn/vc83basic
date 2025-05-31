; Wrappers around assembly language functions to make them callable from C.
; The assembly language functions don't use the C stack, so the wrapper functions
; pop arguments from the C stack and put them in the right places before calling
; the assembly function.
; C prototypes are in test.h.

; cc65 runtime
.import popa, popax, return0, return1

.include "../macros.inc"
.include "../basic.inc"

.bss

; The wrappers for functions that use the carry bit to flag errors return the carry and use these fields to
; save the register values returned from the function.

_AX:
_A: .res 1
_X: .res 1
_Y: .res 1
.export _AX, _A, _X, _Y

_err: .res 1
.export _err

; C exports for non-zero-page data.
; These must have corresponding extern declarations in test.h

.export _BC = BC, _DE = DE
.export _FP0t = FP0t, _FP0e = FP0e, _FP0s = FP0s
.export _FP1t = FP1t, _FP1e = FP1e, _FP1s = FP1s
.export _S0 = S0, _S1 = S1

.export _buffer = buffer
.export _line_buffer = line_buffer

.export _statement_name_table = statement_name_table

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

_decode_expression:
.export _decode_expression
        jmp     decode_expression

_decode_number:
.export _decode_number
        jmp     decode_number

_decode_string:
.export _decode_string
        jsr     decode_string
        sty     _Y
        rts

_decode_name:
.export _decode_name
        jmp     decode_name

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

_encode_byte:
.export _encode_byte
        jsr     encode_byte
        jmp     set_err

; expression.s

_evaluate_expression:
.export _evaluate_expression
        jsr     evaluate_expression
        jmp     set_err

_push_fp0:
.export _push_fp0
        jsr     push_fp0
        jmp     set_err

_pop_fp0:
.export _pop_fp0
        jmp     pop_fp0

_push_string:
.export _push_string
        jsr     push_string
        jmp     set_err

_pop_string:
.export _pop_string
        jmp     pop_string

_stack_alloc:
.export _stack_alloc
        jsr     stack_alloc
        jmp     set_err

_stack_free:
.export _stack_free
        jmp     stack_free

; fp.s

_load_fp0:
.export _load_fp0
        stx     B                       ; Move argument in AX to AY
        ldy     B
        jmp     load_fp0

_load_fp1:
.export _load_fp1
        stx     B                       ; Move argument in AX to AY
        ldy     B
        jmp     load_fp1

_store_fp0:
.export _store_fp0
        stx     B                       ; Move argument in AX to AY
        ldy     B
        jmp     store_fp0

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
        jmp     set_err

_truncate_fp_to_int32:
.export _truncate_fp_to_int32
        jsr     truncate_fp_to_int32
        jmp     set_err

_char_to_digit:
.export _char_to_digit
        jsr     char_to_digit
        jmp     set_err

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
        sta     B                       ; Have to shuffle pos to Y
        jsr     popax                   ; Address of ptr
        ldy     B      
        jsr     string_to_fp
        sty     _Y
        jmp     set_err

_normalize:
.export _normalize
        jsr     normalize
        jmp     set_err

_fadd:
.export _fadd
        stx     B                       ; Move argument in AX to AY
        ldy     B
        jsr     fadd
        jmp     set_err

_fsub:
.export _fsub
        stx     B                       ; Move argument in AX to AY
        ldy     B
        jsr     fsub
        jmp     set_err

_fmul:
.export _fmul
        stx     B                       ; Move argument in AX to AY
        ldy     B
        jsr     fmul
        jmp     set_err

_fdiv:
.export _fdiv
        stx     B                       ; Move argument in AX to AY
        ldy     B
        jsr     fdiv
        jmp     set_err

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
        stx     B                       ; Move argument in AX to AY
        ldy     B
        jsr     fcmp
        bcc     @less                   ; Carry clear means borrow so A < B
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
        jmp     set_err

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
        jmp     set_err

_initialize_name_ptr:
.export _initialize_name_ptr
        jmp     initialize_name_ptr

_advance_name_ptr:
.export _advance_name_ptr
        jsr     advance_name_ptr
        jmp     set_err

_add_variable:
.export _add_variable
        jsr     add_variable
        jmp     set_err

; parser.s

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

_parse_argument_list:
.export _parse_argument_list
        jsr     parse_argument_list
        jmp     set_err

_parse_expression:
.export _parse_expression
        jsr     parse_expression
        jmp     set_err

_parse_name:
.export _parse_name
        jsr     parse_name
        jmp     set_err

_parse_number:
.export _parse_number
        jsr     parse_number
        jmp     set_err

_parse_argument_separator:
.export _parse_argument_separator
        jsr     parse_argument_separator
        jmp     set_err

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
        jmp     set_err

_advance_next_line_ptr:
.export _advance_next_line_ptr
        jmp     advance_next_line_ptr

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

; string.s

_load_s0:
.export _load_s0
        stx     B                       ; Move argument in AX to AY
        ldy     B
        jmp     load_s0

_load_s1:
.export _load_s1
        stx     B                       ; Move argument in AX to AY
        ldy     B
        jmp     load_s1

_read_string:
.export _read_string
        sta     B                       ; Have to shuffle pos to Y
        jsr     popax                   ; Address of ptr
        ldy     B      
        jsr     read_string
        sty     _Y
        jmp     set_err

_string_alloc:
.export _string_alloc
        jsr     string_alloc
        sty     B                       ; Move return from AY to AX
        ldx     B
        jmp     set_err

_compact:
.export _compact
        jmp     compact

; util.s

_copy:
.export _copy
        jmp     copy

_reverse_copy:
.export _reverse_copy
        jmp     reverse_copy

_clear_memory:
.export _clear_memory
        sta     B                       ; Size in A; we need it in Y
        jsr     popax                   ; Address of memory
        ldy     B      
        jmp     clear_memory

_invoke_indexed_vector:
.export _invoke_indexed_vector
        sta     B                       ; Index arrives in A; we need it in Y
        jsr     popax                   ; Address of vector array
        ldy     B      
        jmp     invoke_indexed_vector
