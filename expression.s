.include "macros.inc"
.include "basic.inc"

.zeropage

; Op stack position; points to next open position, so 0 means stack is empty
osp: .res 1
; Value stack position; (same behavior as osp)
vsp: .res 1
; Minimum operator precedence used in process_operators
min_precedence: .res 1

.bss

; Op stack
op_stack: .res OP_STACK_DEPTH
; Value stack
value_stack: .res VALUE_STACK_DEPTH * 2

.code

evaluate_expression:
        ldax    #evaluate_vectors
        jsr     decode_expression
        lda     #PR_CLOSE_PAREN         ; Process any operators not yet processed (except open paren)
        jmp     process_operators

evaluate_vectors:
        .word   evaluate_variable           ; XH_VAR
        .word   evaluate_number             ; XH_NUM
        .word   evaluate_operator           ; XH_OP
        .word   evaluate_unary_operator     ; XH_UNARY_OP
        .word   evaluate_paren              ; XH_PAREN

evaluate_variable:
        jsr     decode_variable         ; Returns variable index in 0
        jsr     set_variable_value_ptr  ; Calculate address of variable
        ldy     #1
        lda     (variable_value_ptr),y  ; High byte of variable value
        tax
        dey
        lda     (variable_value_ptr),y  ; Low byte of variable data
        jmp     push_value

evaluate_number:
        jsr     decode_number           ; Returns number in AX
        jmp     push_value              ; Push number directly

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
        lda     #PR_OPEN_PAREN          ; Push the open paren, which will never be removed by process_operators
        jsr     push_operator
        jsr     evaluate_expression     ; Evaluate the subexpression
        dec     osp                     ; Pop the open paren
        rts

push_operator:
        ldx     osp
        cpx     #OP_STACK_DEPTH         ; If equal then carry ("don't borrow") will be set
        beq     @done                   ; Just return with carry set
        sta     op_stack,x              ; Store operator
        inc     osp                     ; Increment position
@done:
        rts

; Process operators with a precedence >= the precedence passed in A.
; For each such operator, first check if it's a unary operator, then use a jump table to handle other operators.
; The open and close parens will never be handled through the jump table: close paren is never actually put on the
; operator stack, and open parens have such a low precedence that they will never be evaluated.
; A = minimum precedence

process_operators:
        sta     min_precedence          ; Store the minimum precedence
@next:
        ldx     osp                     ; Get operator stack position
        beq     @done                   ; If 0 then nothing to do
        dex                             ; Pre-decrement since osp points to the next empty position
        lda     op_stack,x              ; Get whatever operator it is
        cmp     min_precedence          ; Compare with minimum precedence
        bcc     @done                   ; If carry clear (we had to borrow) then op prec < min prec; stop
        stx     osp                     ; Save this as new operator stack position
        and     #$1F                    ; Keep lower 5 bits
        tay                             ; Index in jump table
        ldax    #operator_vectors
        jsr     invoke_indexed_vector   ; Invoke the vector
        jmp     @next

@done:
        clc                             ; Signal success
        rts

operator_vectors:
        .word   op_add
        .word   op_sub
        .word   op_mul
        .word   op_div
        .word   op_pow
        .word   op_concat
        .word   op_eq
        .word   op_ne
        .word   op_le
        .word   op_lt
        .word   op_ge
        .word   op_gt
        .word   op_and
        .word   op_or
        .word   0
        .word   0
        .word   unary_op_minus
        .word   unary_op_not

op_add:
        jsr     pop_value               ; Get first value
        stax    BC                      ; Save in BC
        jsr     pop_value               ; Get second value
        clc
        adc     B                       ; Add low byte
        sta     B                       ; Store back to B
        txa                             ; High byte into A
        adc     C                       ; Add high byte
        tax                             ; Move to high byte
        lda     B                       ; Load low byte back from B
        jmp     push_value              ; Save on the value stack

op_sub:
        jsr     pop_value               ; Get value
        stax    BC                      ; Save in BC
        jsr     pop_value               ; Get second value
op_sub_bc_from_ax:
        sec
        sbc     B                       ; Subtract low byte
        tay                             ; Move low byte into Y to make room for high byte
        txa                             ; Subtract high byte
        sbc     C
        tax                             ; Result of high byte back into X
        tya                             ; Low byte back into A
        jmp     push_value

unary_op_minus:
        jsr     pop_value               ; Get value
        stax    BC                      ; Save in BC
        lda     #0                      ; Put zero into AX
        tax
        beq     op_sub_bc_from_ax

op_mul:
op_div:
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
        bcs     push_value_0            ; A <> B or A = B

op_ge:
        jsr     compare_values
        bcc     push_value_0            ; A < B
        bcs     push_value_1            ; A <> B or A = B

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
        jsr     pop_value               ; Get value
        stax    BC                      ; Save in BC
        jsr     pop_value        
        tay                             ; Move low byte into Y to make room for high byte
        txa
        cmp     C                       ; Subtract high byte
        bcc     @done                   ; Second value is greater
        tya                             ; Get low byte back
        cmp     B                       ; Subtract low byte
@done:
        rts

; Push the value in AX onto the value stack.
; AX = the value to push
; Returns carry clear if the push was successful, or carry set if there was no room on the stack.
; DE SAFE

push_value_0:
        lda     #0
        beq     push_value_a

push_value_1:
        lda     #1

push_value_a:
        ldx     #0

push_value:
        stax    BC                      ; Store value in BC while we calculate value stack offset
        lda     vsp                     ; Get the current value stack position
        cmp     #VALUE_STACK_DEPTH      ; If equal then carry ("don't borrow") will be set
        beq     @done                   ; Just return with carry set
        asl     A                       ; Multiply by 2; clears carry as long as vsp < 128
        tax                             ; Transfer into X to use as index
        lda     B                       ; Save low byte
        sta     value_stack,x
        lda     C                       ; Store high byte
        sta     value_stack+1,x
        inc     vsp                     ; Increment stack position; carry remains clear for return
@done:
        rts

pop_value: 
        sec                             ; Set carry first in case stack is empty; it is cleared by ASL later
        dec     vsp                     ; Pre-decrement the stack position
        lda     vsp                     ; Get it
        asl     A                       ; Multiply by 2 to generate offset
        tay                             ; Transfer into Y to use as index
        lda     value_stack,y           ; Load low byte into A
        ldx     value_stack+1,y         ; Load high byte into X
        rts

op_and:
        jsr     pop_value
        stax    BC
        jsr     pop_value
        and     B                       ; OR low byte
        tay                             ; Park in Y
        txa                             ; Get high byte
        and     C                       ; OR high byte
        tax                             ; Back into X
        tya                             ; Recover low byte from Y
        jmp     push_value

op_or:
        jsr     pop_value
        stax    BC
        jsr     pop_value
        ora     B                       ; OR low byte
        tay                             ; Park in Y
        txa                             ; Get high byte
        ora     C                       ; OR high byte
        tax                             ; Back into X
        tya                             ; Recover low byte from Y
        jmp     push_value

unary_op_not:
        jsr     pop_value               ; Get value
        stx     B
        clc                             ; Carry will be used to set the result; default is 0
        ora     B                       ; OR the low and high bytes together
        bne     push_value_0            ; Value was not zero so we should return 0
        beq     push_value_1
