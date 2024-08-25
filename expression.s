.include "macros.inc"
.include "basic.inc"

evaluate_expression:
        ldax    #evaluate_vectors
        jsr     decode_expression
        bcs     @done                   ; Expression evaluation failed
        lda     #PR_CLOSE_PAREN         ; Process any operators not yet processed (except open paren)
        jsr     process_operators       ; May fail with carry set
@done:
        rts

evaluate_vectors:
        .word   evaluate_variable-1         ; XH_VAR
        .word   evaluate_operator-1         ; XH_OP
        .word   evaluate_unary_operator-1   ; XH_UNARY_OP
        .word   evaluate_number-1           ; XH_NUM
        .word   evaluate_paren-1            ; XH_PAREN

evaluate_variable:
        jsr     decode_name
        jsr     find_or_add_variable
        bcs     @error                  ; No memory for new variable
        ldy     #1                      ; Start with high byte of value
        lda     (node_ptr),y
        tax
        dey
        lda     (node_ptr),y
        jmp     push_value

@error:
        rts

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
        jsr     evaluate_expression     ; Evaluate the subexpression; may fail
        inc     osp                     ; Pop the open paren (even if evaluate_expression failed)
        rts

push_operator:
        sec                             ; Set carry so can just return failure if stack pointer is 0
        ldx     osp
        beq     @done                   ; If already zero then fail
        dex                             ; Grow down
        sta     op_stack,x              ; Store operator
        stx     osp                     ; Update stack pointer
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
        ldx     osp                     ; Get operator stack position
        cpx     #OP_STACK_SIZE          ; Stack exhausted?
        clc                             ; Clear carry to signal success in case we take BEQ to @done
        beq     @done                   ; If so then done
        lda     op_stack,x              ; Get whatever operator it is
        cmp     min_precedence          ; Compare with minimum precedence
        bcc     @done                   ; If carry clear (we had to borrow) then op prec < min prec; stop
        inc     osp                     ; Move stack position to next operator
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
        .word   0
        .word   0
        .word   0
        .word   0
        .word   0
        .word   0
        .word   0
        .word   0
        .word   0
        .word   0
        .word   0
        .word   unary_op_minus-1

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
        jmp     op_add

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
        stax    BC                      ; Store value in BC while we update stack position
        lda     #2                      ; Allocate 2 bytes for the value
        jsr     stack_alloc
        bcs     @done                   ; Fail if overflow
        lda     B                       ; Save low byte
        sta     primary_stack,x
        lda     C                       ; Store high byte
        sta     primary_stack+1,x
        clc                             ; Signal success
@done:
        rts

pop_value: 
        ldy     psp                     ; Load stack pointer into Y to use as offset
        lda     #2                      ; Free two bytes (retains Y)
        jsr     stack_free
        lda     primary_stack,y         ; Load low byte into A
        ldx     primary_stack+1,y       ; Load high byte into X
        rts

; Allocate space on the stack by moving the stack pointer down by some number of bytes.
; A = the number of bytes to allocate
; Returns carry clear on success and the new stack pointer in both A and X, or carry set on error.
; Y SAFE, BC SAFE, DE SAFE

stack_alloc:
        clc
        sbc     psp                     ; Do A - psp - 1
        bcs     @done                   ; Fail if stack has stack is grown too low
        eor     #$FF                    ; It's already 1 less than we want so inverting gives two's complement
        sta     psp                     ; Update the stack pointer
        tax                             ; Transfer to X to use as pointer
@done:
        rts

; Frees space on the stack by moving the stack pointer up.
; No error checking; the caller must know for sure that there is something on the stack that can be removed.
; X SAFE, Y SAFE, BC SAFE, DE SAFE

stack_free:
        clc
        adc     psp                     ; Add stack pointer to whatever value was passed in
        sta     psp                     ; Save stack pointer back
        rts
