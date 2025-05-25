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

_push_value:
.export _push_value
        jsr     push_value
        jmp     set_err

_pop_value:
.export _pop_value
        jmp     pop_value

_stack_alloc:
.export _stack_alloc
        jsr     stack_alloc
        jmp     set_err

_stack_free:
.export _stack_free
        jmp     stack_free

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

_clear_memory:
.export _clear_memory
        sta     B                       ; Size in A; we need it in Y
        jsr     popax                   ; Address of memory
        ldy     B      
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
        sty     _Y                      ; Save remainder
        rts

_invoke_indexed_vector:
.export _invoke_indexed_vector
        sta     B                       ; Index arrives in A; we need it in Y
        jsr     popax                   ; Address of vector array
        ldy     B      
        jmp     invoke_indexed_vector

_read_number:
.export _read_number
        sta     B                       ; Have to shuffle pos to Y
        jsr     popax                   ; Address of ptr
        ldy     B      
        jsr     read_number
        sty     _Y
        jmp     set_err

_char_to_digit:
.export _char_to_digit
        jsr     char_to_digit
        jmp     set_err

_format_number:
.export _format_number
        jmp     format_number
