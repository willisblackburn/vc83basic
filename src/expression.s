; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

; stack must be page-aligned
.assert <stack = 0, error

; We depend on the values being at offset 0.
.assert Value::number_value = 0, error
.assert Value::string_value_ptr = 0, error

.assert TOK_ADD = $20, error
.assert TOK_LEN = $80, error
.assert PR_OPEN_PAREN = TYPE_NUMBER, error

; Evaluates an expression and leaves the result in FP0 (number) or S0 (string header), with type in expr_type.
; An expression is a primary expression, optionally followed by a binary operator and another expression.
; If we're here, there *must* be an expression. The expression ends when we don't find a binary operator
; after the primary expression.

evaluate_expression:
        phzp    VAR_NAME_STATE, VAR_NAME_STATE_SIZE         ; Remember the decoded name
        lda     #PR_OPEN_PAREN          ; Push the open paren, which will never be removed by process_operators
after_operator:
        jsr     push_operator
next_expression:
        jsr     get_byte                        ; Get the next thing
        cmp     #TOK_ADD                        ; Check for unary op cases
        beq     next_expression                 ; Unary + does nothing
        ldx     #PR_UNARY_OP | TOK_UNARY_MINUS
        cmp     #TOK_SUB
        beq     @unary_operator
        ldx     #PR_UNARY_OP | TOK_UNARY_NOT
        cmp     #TOK_NOT
        beq     @unary_operator
        jsr     @dispatch               ; JSR to dispatcher so we can just RTS from handlers
        jsr     peek_byte               ; Check if an operator follows
        and     #$F0
        cmp     #TOK_ADD
        beq     @operator
        lda     #PR_CLOSE_PAREN         ; Process any operators not yet processed (except open paren)
        jsr     process_operators
        inc     op_stack_pos            ; Pop the open paren
        plzp    VAR_NAME_STATE, VAR_NAME_STATE_SIZE         ; Recover the decoded name
        lda     expr_type               ; Return expr_type in A and set flags (Z=1 for number, Z=0 for string)
        rts

@unary_operator:
        txa                             ; The operator is in X; move it to A
        bne     after_operator          ; Unconditional

@operator:
        jsr     get_byte                ; Return the operator in A
        and     #$0F                    ; Get the operator number
        pha                             ; Keep on the stack while we process higher-precedence operators
        lsr     A                       ; Divide by 2        
        tax                             ; Move into X to use as index
        lda     operator_precedence_table,x ; Look up the precedence value
        jsr     process_operators       ; Handle operators >= the precedence of this operator
        jsr     push_pending            ; Push result for the new operator
        pla                             ; Get the operator value again
        tay                             ; Hold in Y
        lsr     A                       ; Divide by 2 (again)
        tax                             ; Move into X to use as index (again)
        tya                             ; Operator value back into A
        ora     operator_precedence_table,x ; OR the precedence value
        jmp     after_operator

@dispatch:
        ldy     #TYPE_NUMBER            ; Default expr_type to TYPE_NUMBER (0)
        sty     expr_type
        cmp     #TOK_LPAREN
        beq     evaluate_paren
        cmp     #TOK_NUM
        beq     evaluate_number
        cmp     #TOK_STRING
        beq     evaluate_string
        cmp     #TOK_NAME
        beq     evaluate_variable
        inc     line_pos                ; None of the above; assume it's a function and skip '('
        jsr     dispatch_function
        inc     line_pos                ; Skip ')'
        rts

evaluate_paren:
        lda     #PR_OPEN_PAREN          ; Push the open paren, which will never be removed by process_operators
        jsr     push_operator
        jsr     evaluate_expression     ; Evaluate the subexpression; may fail
        inc     op_stack_pos            ; Pop the open paren (even if evaluate_expression failed)
        inc     line_pos                ; Consume the ')'
        rts

evaluate_number:
        ldax    line_ptr
        ldy     line_pos
        jsr     string_to_fp            ; May fail with carry set
        bcs     raise_format_error
        sty     line_pos                ; Update line_pos
        rts

raise_format_error:
        raise   ERR_FORMAT_ERROR

evaluate_string:
        jsr     get_byte                ; A = length, line_pos now points to first character
        jsr     string_alloc_for_copy   ; Allocates on heap, sets dst_ptr = string_ptr + 1
        mvax    string_ptr, S0          ; S0 = string header pointer
        inc     expr_type               ; TYPE_STRING
        lda     line_ptr                ; Calculate source address: line_ptr + line_pos
        clc
        adc     line_pos
        sta     src_ptr
        lda     line_ptr+1
        adc     #0
        sta     src_ptr+1               ; src_ptr points to source characters
        tya                             ; A = length
        sec                             ; SEC + ADC = length + line_pos + 1
        adc     line_pos
        sta     line_pos                ; Advance line_pos past characters and ending quote
        tya                             ; A = length
        jmp     copy_a                  ; Copies A bytes from src_ptr to dst_ptr and returns

evaluate_variable:
        jsr     get_variable_2
        lda     var_name_type
        beq     @number
        inc     expr_type               ; TYPE_STRING
        ldy     #0
        lda     (name_ptr),y
        sta     S0
        iny
        lda     (name_ptr),y
        sta     S0+1
        rts
@number:
        lday    name_ptr                ; Load directly into FP0
        jmp     load_fp0

; Operator precedence table
; We index this by the operator index divided by 2.

operator_precedence_table:
        .byte   PR_ADD                  ; +, -
        .byte   PR_MUL                  ; *, /
        .byte   PR_POW                  ; ^, &
        .byte   PR_RELATIONAL           ; =, <>
        .byte   PR_RELATIONAL           ; <=, <
        .byte   PR_RELATIONAL           ; >=, >
        .byte   PR_LOGICAL              ; AND, OR

; Evaluate a number of arguments. The argument list will either end in a 0 (as in a series of arguments for a
; statement) or in a close paren (as in a DIM statement, array reference, or function call).
; A = the number of arguments expected
; Returns the number of arguments that were expected but not found; will be negative if too many argument found.

evaluate_argument_list:
        pha                             ; Save expected count
        jsr     peek_byte
        cmp     #TOK_RPAREN
        beq     @done
@loop:
        jsr     evaluate_expression
        jsr     push_pending            ; Push result for function prolog / statement
        tsx
        dec     $101,x                  ; Decrement remaining
        jsr     peek_byte
        cmp     #TOK_COMMA
        bne     @done                   ; No comma, stop
        inc     line_pos                ; Skip comma
        jmp     @loop                   ; And continue
@done:
        pla                             ; Return remaining count
        rts

push_operator:
        ldx     op_stack_pos
        raieq   ERR_EXPRESSION_TOO_COMPLEX   ; If already zero then fail
        dex                             ; Grow down
        sta     op_stack,x              ; Store operator
        stx     op_stack_pos            ; Update stack pointer
        rts

; Process operators with a precedence >= the precedence passed in A.
; The open and close parens will never be handled through the jump table: close paren is never actually put on the
; operator stack, and open parens have such a low precedence that they will never be evaluated.
; Because evaluate_expression always pushes a PR_OPEN_PAREN sentinel ($00) beforehand and min_precedence is always
; >= PR_CLOSE_PAREN ($20), the operator stack will never underflow.
; A = minimum precedence

process_operators:
        sta     min_precedence          ; Store the minimum precedence
@next:
        ldx     op_stack_pos            ; Get operator stack position
        lda     op_stack,x              ; Get whatever operator it is
        cmp     min_precedence          ; Compare with minimum precedence
        bcc     @done                   ; If carry clear (we had to borrow) then op prec < min prec; stop
        jsr     @dispatch               ; JSR to operator evaluator so RTS takes us back here
        jmp     @next

@dispatch:
        inc     op_stack_pos            ; Move stack position to next operator
        and     #$0F                    ; Keep lower 4 bits
        tax                             ; Set up operator vector index
        lda     operator_vectors_h,x    ; Invoke vector
        pha
        lda     operator_vectors_l,x
        pha

@done:
        rts                             ; This is either RTS from process_operators or JMP to operator handler

op_concat:
        lda     expr_type
        ldx     stack_pos
        and     stack+Value::type,x     ; Must both be TYPE_STRING ($01)
        bne     @type_ok
        jmp     raise_type_mismatch
@type_ok:
        jsr     push_string_s0          ; Push right operand for GC safety
        lday    S0                      ; Right string header
        jsr     load_s1                 ; Convert to data pointer in S1, A = right length
        sta     E
        ldx     stack_pos               ; Get stack pointer
        lda     stack+.sizeof(Value)+Value::string_value_ptr,x
        ldy     stack+.sizeof(Value)+Value::string_value_ptr+1,x
        jsr     load_s0                 ; Convert to data pointer in S0, A = left length
        sta     D
        clc
        adc     E                       ; Total length = D + E
        bcs     @out_of_range
        jsr     string_alloc_for_copy
        ldax    S0                      ; Copy S0 to dst_ptr
        ldy     D
        jsr     copy_y_from
        ldax    S1                      ; Copy S1
        ldy     E
        jsr     copy_y_from
        lda     #2 * .sizeof(Value)
        jsr     stack_free              ; Pop both strings from the stack
        mvax    string_ptr, S0
        mva     #TYPE_STRING, expr_type
        rts

@out_of_range:
        jmp     raise_out_of_range

op_eq:
        jsr     compare_values
op_eq_tail:
        beq     set_value_1             ; A = B
        bne     set_value_0             ; A <> B

op_ne:
        jsr     compare_values
op_ne_tail:
        bne     set_value_1             ; A <> B
        beq     set_value_0             ; A = B

op_lt:
        jsr     compare_values
        bcc     set_value_1             ; A < B
        bcs     set_value_0             ; A >= B

op_ge:
        jsr     compare_values
        bcc     set_value_0             ; A < B
        bcs     set_value_1             ; A >= B

op_gt:
        jsr     compare_values
        bcs     op_ne_tail              ; A >= B

set_value_0:
        jmp     clear_fp0

op_le:
        jsr     compare_values
        bcs     op_eq_tail

set_value_1:
        jmp     load_one_fp0

compare_num_values:
        jsr     load_fp1
        jsr     swap_fp0_fp1
        jmp     fcmp_2

; Compares two strings: right operand in S0, left on stack.
; Returns flags based on comparison.
; CMP s1 len, s2 len
; C=0 (borrow) if s1 len < s2 len
; C=1 (not borrow) if s1 len >= s2 len

compare_string_values:
        lday    S0                      ; Right string header pointer
        jsr     load_s1                 ; Convert to data pointer in S1, A = right string length
        sta     E                       ; Length of second string in E
        jsr     pop_string_s0           ; Get first string from stack into S0
        sta     D                       ; Length of first string in D
        cmp     E                       ; Compare first string length to second
        bcc     @use_first_string_length
        lda     E                       ; Replace length in A with the shorter second string length 
@use_first_string_length:
        sta     B                       ; Store shortest string length in B
        ldy     #$FF                    ; Start at first character ($FF because we pre-increment Y)
@next_character:
        iny
        cpy     B                       ; Out of characters?
        beq     @compare_lengths        ; Yes
        lda     (S0),y                  ; Compare the next character
        cmp     (S1),y
        beq     @next_character
        rts                             ; Return with the flags from the comparison

@compare_lengths:
        lda     D                       ; Characters are the same, so shorter string is lesser or equal
        cmp     E
        rts

compare_values:
        lda     expr_type               ; Right operand type
        ldx     stack_pos               ; Get stack pointer
        cmp     stack+Value::type,x     ; Type of first argument
        beq     @match
        jmp     raise_type_mismatch
@match:
        cmp     #TYPE_STRING            ; Is it a string?
        beq     @string
        lda     #>(compare_num_values-1)
        ldx     #<(compare_num_values-1)
        jmp     call_binary_operator
@string:
        mva     #TYPE_NUMBER, expr_type ; Comparison result is always a number
        jmp     compare_string_values

; Take the two values from the top of the stack and invoke a binary operator.
; The operator handler address -1 is passed in XA (note least-significant byte is in X).
; Right operand is already in FP0.
; Left operand is popped from value stack and its address passed in AY.

call_binary_operator:
        phax                            ; Push operator handler address -1 onto the stack so we can RTS to it
        lda     expr_type               ; Make sure right operand is TYPE_NUMBER (0)
        beq     @type_ok
        jmp     raise_type_mismatch
@type_ok:
        jsr     stack_free_value_with_type ; A is 0, so checks left operand is TYPE_NUMBER (0)
        txa                             ; Original value of stack_pos, returned in X
        ldy     #>stack                 ; Stack page
        rts                             ; JMP to the operator handler

; Since we're passing the address in XA, be sure to do LDA second, since it's the high byte and
; is guaranteed not to be zero.

op_mul:
        ldx     #<(fmul-1)
        lda     #>(fmul-1)
        bne     call_binary_operator

op_div_handler:
        jsr     load_fp1
        jsr     swap_fp0_fp1
        jmp     fdiv_2

op_div:
        ldx     #<(op_div_handler-1)
        lda     #>(op_div_handler-1)
        bne     call_binary_operator

op_pow_handler:
        stay    DE                      ; Save pointer to base in DE
        lday    #fpow_exponent
        jsr     store_fp0               ; Store exponent in fpow_exponent
        lday    DE
        jsr     load_fp0                ; Load base into FP0
        lday    #fpow_exponent          ; Pointer to exponent in AY
        jmp     fpow                    ; fpow(base in FP0, exponent in AY)

op_pow:
        ldx     #<(op_pow_handler-1)
        lda     #>(op_pow_handler-1)
        bne     call_binary_operator

op_sub:
        jsr     fneg                    ; FP0 = -right
        ldx     #<(fadd-1)              ; (-right) + left = left - right
        lda     #>(fadd-1)
        bne     call_binary_operator
        
op_add:
        ldx     #<(fadd-1)
        lda     #>(fadd-1)
        bne     call_binary_operator

unary_op_not:
        lda     expr_type
        beq     @type_ok
        jmp     raise_type_mismatch
@type_ok:
        lda     FP0e
        bne     @false
        jmp     load_one_fp0
@false:
        jmp     clear_fp0

unary_op_minus:
        lda     expr_type
        bne     @type_mismatch
        jmp     fneg
@type_mismatch:
        jmp     raise_type_mismatch

; Push the value in FP0 onto the value stack.
; FP0 = the value to push
; DE SAFE

push_int_fp0:
        jsr     int_to_fp

; Fall through

push_fp0:
        jsr     stack_alloc_value       ; Returns with A set to the offset
        tay                             ; Stack offset into Y
        lda     #TYPE_NUMBER            ; Assign the number type
        sta     stack+Value::type,y
        tya                             ; Low byte of store address
        ldy     #>stack                 ; Stack page
        jmp     store_fp0               ; Store FP0 in the AY address

pop_int_fp0:
        jsr     pop_fp0
        jmp     truncate_fp_to_int

; Pops a value from the stack into an FP register.
; DE SAFE

.assert TYPE_NUMBER = $00, error

pop_fp0:
        lda     #TYPE_NUMBER            ; Make sure it's a number
        jsr     stack_free_value_with_type
        txa                             ; Original stack position into A to use as low byte of pointer
        ldy     #>stack                 ; Stack page
        jmp     load_fp0                ; Load value into FP0

; Pushes the string referenced by string_ptr onto the stack. This works because this function is only called after
; we have generated a new string.
; DE SAFE

; Pushes the pending value (FP0 or S0 based on expr_type) onto the value stack.
push_pending:
        lda     expr_type
        bne     @string
        jmp     push_fp0
@string:
        jmp     push_string_s0

; Pushes the string referenced by string_ptr onto the stack. This works because this function is only called after
; we have generated a new string.
; S0 is updated to string_ptr.
; DE SAFE

push_string:
        mvax    string_ptr, S0
; Fall through
push_string_s0:
        jsr     stack_alloc_value
        tay
        lda     #TYPE_STRING            ; Assign the string type
        sta     stack+Value::type,y
        lda     S0                      ; Copy low byte of string address
        sta     stack+Value::string_value_ptr,y     ; Save low and high byte of string address
        lda     S0+1                    ; High byte
        sta     stack+Value::string_value_ptr+1,y   ; Carry still clear for return
        rts

pop_string_s0:
        jsr     pop_string
        jmp     load_s0

; Pops the string value from the stack and returns the address in AY.
; BC SAFE, DE SAFE

pop_string:
        lda     #TYPE_STRING            ; Make sure it's a string
        jsr     stack_free_value_with_type          ; Even if it's not a string, load the address unconditionally
        lda     stack+Value::string_value_ptr,x     ; Return with address in AX
        ldy     stack+Value::string_value_ptr+1,x   
        rts

; Allocate space on the stack by moving the stack pointer down by some number of bytes.
; A = the number of bytes to allocate
; Returns carry clear on success and the new stack pointer in A, or carry set on error.
; X SAFE, Y SAFE, BC SAFE, DE SAFE

stack_alloc_value:
        lda     #.sizeof(Value)
stack_alloc:
        clc
        sbc     stack_pos               ; Do A - stack_pos - 1
        bcs     raise_stack             ; Fail if stack has stack is grown too low
        eor     #$FF                    ; It's already 1 less than we want so inverting gives two's complement
        sta     stack_pos               ; Update the stack pointer
        rts

raise_stack:
        raise   ERR_STACK

; Frees space on the stack by moving the stack pointer up.
; No error checking; the caller must know for sure that there is something on the stack that can be removed.
; X SAFE, Y SAFE, BC SAFE, DE SAFE

stack_free_value:
        lda     #.sizeof(Value)
stack_free:
        clc
        adc     stack_pos               ; Add stack pointer to whatever value was passed in
        sta     stack_pos               ; Save stack pointer back
        rts                             ; Carry should be clear here because stack should not underflow

; Frees the space used on the stack by one value and checks the type of that value.
; A = the type to check
; On success, carry will be clear and X will point to the previous value of stack_pos (where the freed value was).
; Y SAFE, BC SAFE, DE SAFE

stack_free_value_with_type:
        ldx     stack_pos               ; Get stack pointer
        cmp     stack+Value::type,x     ; Test the type
        beq     stack_free_value        ; Type check succeeded so remove value from stack
raise_type_mismatch:
        raise   ERR_TYPE_MISMATCH       ; Not the expected type

op_and:
        jsr     set_up_logical_op
        and     D                       ; AND low bytes
        pha
        txa                             ; High byte into A
        and     E                       ; AND high bytes

; Fall through

finish_logical_op:
        tax
        mva     #TYPE_NUMBER, expr_type ; Result is TYPE_NUMBER
        pla                             ; Recover low byte
        jmp     int_to_fp

op_or:
        jsr     set_up_logical_op
        ora     D                       ; OR low bytes
        pha
        txa                             ; High byte into A
        ora     E                       ; OR low bytes
        jmp     finish_logical_op

set_up_logical_op:
        lda     expr_type
        bne     raise_type_mismatch
        jsr     truncate_fp_to_int      ; FP0 right operand -> int in AX
        stax    DE                      ; Store returned value in DE
        jsr     pop_fp0                 ; Left operand -> FP0
        jmp     truncate_fp_to_int

operator_vectors_l:
        .byte   <(op_add-1)
        .byte   <(op_sub-1)
        .byte   <(op_mul-1)
        .byte   <(op_div-1)
        .byte   <(op_pow-1)
        .byte   <(op_concat-1)
        .byte   <(op_eq-1)
        .byte   <(op_lt-1)
        .byte   <(op_gt-1)
        .byte   <(op_ne-1)
        .byte   <(op_le-1)
        .byte   <(op_ge-1)
        .byte   <(op_and-1)
        .byte   <(op_or-1)
        .byte   <(unary_op_minus-1)
        .byte   <(unary_op_not-1)

operator_count = * - operator_vectors_l

; We can only handle 16 operators (14 binary + 2 unary).
.assert operator_count <= 16, error

operator_vectors_h:
        .byte   >(op_add-1)
        .byte   >(op_sub-1)
        .byte   >(op_mul-1)
        .byte   >(op_div-1)
        .byte   >(op_pow-1)
        .byte   >(op_concat-1)
        .byte   >(op_eq-1)
        .byte   >(op_lt-1)
        .byte   >(op_gt-1)
        .byte   >(op_ne-1)
        .byte   >(op_le-1)
        .byte   >(op_ge-1)
        .byte   >(op_and-1)
        .byte   >(op_or-1)
        .byte   >(unary_op_minus-1)
        .byte   >(unary_op_not-1)

.assert (* - operator_vectors_h) = operator_count, error
