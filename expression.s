.include "macros.inc"
.include "basic.inc"

; stack must be page-aligned
.assert <stack = 0, error

evaluate_expression:
        ldax    #evaluate_vectors
        jsr     decode_expression
        bcs     @done                   ; Expression evaluation failed
        lda     #PR_CLOSE_PAREN         ; Process any operators not yet processed (except open paren)
        jsr     process_operators       ; May fail with carry set
@done:
        rts

evaluate_vectors:
        .word   evaluate_unary_operator-1   ; XH_UNARY_OP
        .word   evaluate_operator-1         ; XH_OP
        .word   evaluate_number-1           ; XH_NUMBER
        .word   evaluate_variable-1         ; XH_VAR
        .word   evaluate_paren-1            ; XH_PAREN

evaluate_variable:
        jsr     decode_name
        jsr     find_or_add_variable
        bcs     @error                  ; No memory for new variable
        lda     #.sizeof(Float)         ; Make space on the stack
        jsr     stack_alloc
        bcs     @error
        ldx     #>stack                 ; Segment of stack
        stax    dst_ptr                 ; Copy to stack
        ldax    name_ptr                ; Copy from variable data
        ldy     #.sizeof(Float)
        jsr     copy_y_from
        clc                             ; Signal success
@error:
        rts

evaluate_number:
        jsr     decode_number           ; Returns number in FP0
        jmp     push_fp0                ; Push number

evaluate_operator:
        jsr     decode_operator         ; Return the operator in A
        pha                             ; Keep on the stack while we process higher-precedence operators
        lsr     A                       ; Divide by 2        
        tax                             ; Move into X to use as index
        lda     operator_precedence_table,x ; Look up the precedence value
        jsr     process_operators       ; Handle operators >= the precedence of this operator
        pla                             ; Get the operator value again
        tay                             ; Hold in Y
        lsr     A                       ; Divide by 2 (again)
        tax                             ; Move into X to use as index (again)
        tya                             ; Operator value back into A
        ora     operator_precedence_table,x ; OR the precedence value
        jmp     push_operator           ; Push this operator onto the stack

evaluate_unary_operator:
        jsr     decode_unary_operator   ; Get the unary operator
        ora     #PR_UNARY_OP            ; Unary ops have highest precedence and are right-assoc so don't do anything
        jmp     push_operator           ; Except push the operator onto the stack

evaluate_paren:
        inc     line_pos                ; Consume the '('
        lda     #PR_OPEN_PAREN          ; Push the open paren, which will never be removed by process_operators
        jsr     push_operator
        jsr     evaluate_expression     ; Evaluate the subexpression; may fail
        inc     op_stack_pos            ; Pop the open paren (even if evaluate_expression failed)
        rts

push_operator:
        sec                             ; Set carry so can just return failure if stack pointer is 0
        ldx     op_stack_pos
        beq     @done                   ; If already zero then fail
        dex                             ; Grow down
        sta     op_stack,x              ; Store operator
        stx     op_stack_pos            ; Update stack pointer
        clc                             ; Success
@done:
        rts

; Process operators with a precedence >= the precedence passed in A.
; The open and close parens will never be handled through the jump table: close paren is never actually put on the
; operator stack, and open parens have such a low precedence that they will never be evaluated.
; A = minimum precedence

process_operators:
        sta     min_precedence          ; Store the minimum precedence
@next:
        ldx     op_stack_pos            ; Get operator stack position
        cpx     #OP_STACK_SIZE          ; Stack exhausted?
        clc                             ; Clear carry to signal success in case we take BEQ to @done
        beq     @done                   ; If so then done
        lda     op_stack,x              ; Get whatever operator it is
        cmp     min_precedence          ; Compare with minimum precedence
        bcc     @done                   ; If carry clear (we had to borrow) then op prec < min prec; stop
        inc     op_stack_pos            ; Move stack position to next operator
        and     #$1F                    ; Keep lower 5 bits
        tay                             ; Index in jump table
        ldax    #operator_vectors
        jsr     invoke_indexed_vector   ; Invoke the vector
        bcc     @next                   ; If operator success then continue, else fail
@done:
        rts

operator_vectors:
        .word   op_add-1
        .word   op_sub-1
        .word   op_mul-1
        .word   op_div-1
        .word   op_pow-1
        .word   op_concat-1
        .word   op_eq-1
        .word   op_lt-1
        .word   op_gt-1
        .word   op_ne-1
        .word   op_le-1
        .word   op_ge-1
        .word   op_and-1
        .word   op_or-1
        .word   0
        .word   0
        .word   unary_op_minus-1
        .word   unary_op_not-1

op_sub:
        lda     #>(fsub-1)
        ldx     #<(fsub-1)
        jmp     call_binary_operator_push
        
op_add:
        lda     #>(fadd-1)
        ldx     #<(fadd-1)
        jmp     call_binary_operator_push

op_mul:
        lda     #>(fmul-1)
        ldx     #<(fmul-1)
        jmp     call_binary_operator_push

op_div:
        lda     #>(fdiv-1)
        ldx     #<(fdiv-1)
        jmp     call_binary_operator_push

op_pow:
op_concat:
        jmp     op_add

op_eq:
        jsr     compare_values
        bcc     push_value_0            ; A < B
        bne     push_value_0            ; A <> B
        beq     push_value_1            ; A = B

op_ne:
        jsr     compare_values
        bcc     push_value_1            ; A < B
        bne     push_value_1            ; A <> B
        beq     push_value_0            ; A = B

op_le:
        jsr     compare_values
        bcc     push_value_1            ; A < B
        bne     push_value_0            ; A <> B
        beq     push_value_1            ; A = B

op_lt:
        jsr     compare_values
        bcc     push_value_1            ; A < B
        bcs     push_value_0            ; A >= B

op_ge:
        jsr     compare_values
        bcc     push_value_0            ; A < B
        bcs     push_value_1            ; A >= B

op_gt:
        jsr     compare_values
        bcc     push_value_0            ; A < B
        bne     push_value_1            ; A <> B
        beq     push_value_0            ; A = B

; Compares two values from the stack returns flags based on the comparison.
; On return, C ("not borrow") will be or clear if the second value is greater than the first (B > A or A < B)
; or set if the second value is less than or equal to the first (B <= A or A >= B).
; If carry is set, then Z will be also be set if the values are equal or clear if they are not.

compare_values:
        lda     #>(fcmp-1)
        ldx     #<(fcmp-1)

; Fall through

; Take the two values from the top of the stack and invoke a binary operator.
; The operator handler address -1 is passed in XA (note least-significant byte is in X).
; Given an expression like 3/2, we will push 3 onto the stack, then 2, so 2 is at top of stack, and therefore the
; value we pop first goes into FP1, then the other info FP0.

call_binary_operator:
        phax                            ; Push operator handler address -1 onto the stack so we can RTS to it
        ldx     #FP1
        jsr     pop_fpx                 ; Top value into FP1
        jsr     pop_fp0                 ; Next value into FP0
        rts                             ; This does JMP to the operator handler

; Invokes a binary operator and pushes the result back.

call_binary_operator_push:
        jsr     call_binary_operator
        jmp     push_fp0

unary_op_minus:
        jsr     pop_fp0                 ; Get value at top of stack
        jsr     fneg                    ; Negate it
        jmp     push_fp0                ; Return to stack

unary_op_not:
        jsr     pop_fp0                 ; Get value
        jsr     fp0_is_zero
        bne     push_value_0            ; Value was not zero so we should return 0
        beq     push_value_1

; Push the value in an FP register onto the value stack.
; X = #FP0 or #FP1 (the _fp0 entry points set this to FP0)
; FP0/1 = the value to push
; Returns carry clear if the push was successful, or carry set if there was no room on the stack.
; BC SAFE, DE SAFE

push_value_0:
        jsr     clear_fp0
        jmp     push_fp0

push_value_1:
        lday    #fp_one
        jsr     load_fp0

push_fp0:
        ldx     #FP0
push_fpx:
        lda     #.sizeof(Float)         ; Allocate enough space for a float on the stack
        jsr     stack_alloc             ; Returns with A set to the offset
        bcs     @done                   ; Fail if overflow
        ldy     #>stack                 ; Segment of stack
        jsr     store_fpx               ; Store FPx in the AY address
        clc                             ; Signal success
@done:
        rts

; Pops a value from the stack into an FP register. Never fails, since we can trust the parser to only tokenize
; well-formed expressions.
; FP0/1 = the value to push

pop_fp0:
        ldx     #FP0
pop_fpx: 
        ldy     stack_pos               ; Load stack pointer into Y to use as offset
        lda     #.sizeof(Float)         ; Free space for float
        jsr     stack_free
        tya                             ; Previous position back in A to use as pointer
        ldy     #>stack                 ; Segment of stack
        jsr     load_fpx                ; Load value into FPx
        rts

; Allocate space on the stack by moving the stack pointer down by some number of bytes.
; A = the number of bytes to allocate
; Returns carry clear on success and the new stack pointer in A, or carry set on error.
; X SAFE, Y SAFE, BC SAFE, DE SAFE

stack_alloc:
        clc
        sbc     stack_pos               ; Do A - stack_pos - 1
        bcs     @done                   ; Fail if stack has stack is grown too low
        eor     #$FF                    ; It's already 1 less than we want so inverting gives two's complement
        sta     stack_pos               ; Update the stack pointer
@done:
        rts

; Frees space on the stack by moving the stack pointer up.
; No error checking; the caller must know for sure that there is something on the stack that can be removed.
; X SAFE, Y SAFE, BC SAFE, DE SAFE

stack_free:
        clc
        adc     stack_pos               ; Add stack pointer to whatever value was passed in
        sta     stack_pos               ; Save stack pointer back
        rts

op_and:
        jsr     set_up_logical_op
        and     D                       ; AND low bytes
        pha
        txa                             ; High byte into A
        and     E                       ; AND high bytes

; Fall through

finish_logical_op:
        tax
        pla                             ; Recover low byte
        jsr     int_to_fp               ; Convert back into FP value
        jmp     push_fp0                ; Back onto stack

op_or:
        jsr     set_up_logical_op
        ora     D                       ; OR low bytes
        pha
        txa                             ; High byte into A
        ora     E                       ; OR low bytes
        jmp     finish_logical_op

set_up_logical_op:
        jsr     pop_fp0
        jsr     truncate_fp_to_int
        stax    DE                      ; Store returned value in DE
        jsr     pop_fp0
        jsr     truncate_fp_to_int
        rts                             ; Return with value in DE
