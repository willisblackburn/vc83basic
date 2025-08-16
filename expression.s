.include "macros.inc"
.include "basic.inc"

; stack must be page-aligned
.assert <stack = 0, error

; We depend on the values being at offset 0.
.assert Value::number_value = 0, error
.assert Value::string_value_ptr = 0, error

evaluate_vectors:
        .word   evaluate_unary_operator-1   ; XH_UNARY_OP
        .word   evaluate_operator-1         ; XH_OP
        .word   evaluate_number-1           ; XH_NUMBER
        .word   evaluate_string-1           ; XH_STRING
        .word   evaluate_variable-1         ; XH_VAR
        .word   evaluate_paren-1            ; XH_PAREN

; Fall through

; Evaluate a full expression.
; Evaluating an expression often involves evaluating names, and decoding names affects decode_name_ptr and related
; values. Sometimes the caller is using them (for example, they might identify the variable that LET is setting), so
; we save them on the stack and restore them before returning.

evaluate_expression:
        phzp    DECODE_NAME_STATE, DECODE_NAME_STATE_SIZE   ; Remember the decoded name
        lda     #PR_OPEN_PAREN          ; Push the open paren, which will never be removed by process_operators
        jsr     push_operator
        ldax    #evaluate_vectors
        jsr     decode_expression
        bcs     @error                  ; Expression evaluation failed
        lda     #PR_CLOSE_PAREN         ; Process any operators not yet processed (except open paren)
        jsr     process_operators       ; May fail with carry set
@error:
        inc     op_stack_pos            ; Pop the open paren (even if evaluation failed)
        plzp    DECODE_NAME_STATE, DECODE_NAME_STATE_SIZE   ; Recover the decoded name
        rts

; Evaluate a number of arguments. The argument list will either end in a 0 (as in a series of arguments for a
; statement) or in a close paren (as in a DIM statement, array reference, or function call).
; A = the number of arguments expected
; Returns the number of arguments that were expected but not found; will be negative if too many argument found.

evaluate_argument_list:
        pha                             ; Save the number of arguments expected on the stack
@next:
        ldy     line_pos                ; Peek at next byte in token stream
        lda     (line_ptr),y
        beq     @done                   ; Was 0
        cmp     #')'
        beq     @done                   ; Was ')'
        cmp     #','                    ; If it's a comma then just skip it
        bne     @no_comma
        inc     line_pos                ; Skip the comma
@no_comma:
        jsr     evaluate_expression     ; Read the next expression
        bcs     @error                  ; Possibly type error in expression
        tsx                             ; Get ready to access stack
        dec     $101,x                  ; Decrement the number of arguments
        jmp     @next                   ; Continue on

@done:
        inc     line_pos                ; Skip over the terminating byte
        clc
@error:
        pla                             ; Return number of arguments read
        rts

evaluate_variable:
        jsr     decode_name
evaluate_decoded_variable:
        jsr     find_or_add_variable
        bcs     @error                  ; No memory for new variable
        jsr     stack_alloc_value
        bcs     @error
        tay                             ; Stack position into Y to set type
        lda     decode_name_type        ; Set type of value on stack
        sta     stack+Value::type,y
        tax                             ; Move the type into X
        tya                             ; Use as low byte of copy address
        ldy     type_size_table,x       ; Replace Y with the size of the type
        ldx     #>stack                 ; Stack page
        stax    dst_ptr                 ; Copy to stack
        ldax    name_ptr                ; Copy from variable data
        jsr     copy_y_from
        clc                             ; Signal success
@error:
        rts

evaluate_number:
        jsr     decode_number           ; Returns number in FP0
        jmp     push_fp0                ; Push number

evaluate_operator:
        jsr     decode_byte             ; Return the operator in A
        and     #<~TOKEN_OP
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
        jsr     decode_byte             ; Get the unary operator
        and     #<~TOKEN_UNARY_OP
        ora     #PR_UNARY_OP            ; Unary ops have highest precedence and are right-assoc so don't do anything
        jmp     push_operator           ; Except push the operator onto the stack

evaluate_paren:
        inc     line_pos                ; Consume the '('
        lda     #PR_OPEN_PAREN          ; Push the open paren, which will never be removed by process_operators
        jsr     push_operator
        jsr     evaluate_expression     ; Evaluate the subexpression; may fail
        inc     op_stack_pos            ; Pop the open paren (even if evaluate_expression failed)
        inc     line_pos                ; Consume the ')'
        rts

evaluate_string:
        jsr     decode_string           ; Returns pointer in AX
        jmp     push_string

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
        jmp     op_add

op_concat:
        jsr     pop_string              ; Get the second string
        jsr     load_s1                 ; Load into S1
        sta     E                       ; Length of second string in E
        jsr     pop_string              ; Get first string
        jsr     load_s0                 ; First string into S0
        sta     D                       ; Length of first string in D
        clc
        adc     E                       ; Get total length of string
        bcs     @error                  ; Combined string is too long
        jsr     string_alloc            ; Otherwise A is length of new string; allocate it
        sta     dst_ptr                 ; New space is destination for the copy
        inc     dst_ptr                 ; Move past length byte
        bne     @skip_iny
        iny
@skip_iny:
        sty     dst_ptr+1
        ldax    S0                      ; Copy S0 to dst_ptr
        ldy     D
        jsr     copy_y_from
        ldax    S1                      ; Copy S1
        ldy     E
        jsr     copy_y_from
        ldax    string_ptr              ; Happily, string_ptr is still the address of the new string
        jsr     push_string
@error:
        rts

; Compares two strings from the stack returns flags based on the comparison.
; CMP s1 len, s2 len
; C=0 (borrow) if s1 len < s2 len
; C=1 (not borrow) if s1 len >= s2 len

compare_string_values:
        jsr     pop_string              ; Get second string
        jsr     load_s1                 ; Second string into S1
        sta     E                       ; Length of second string in E
        jsr     pop_string              ; Get first string
        jsr     load_s0                 ; First string into S0
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
        ldy     stack_pos               ; Get stack pointer
        lda     stack+Value::type,y                 ; Type of first argument
        cmp     stack+.sizeof(Value)+Value::type,y  ; Type of second argument
        beq     @same_types
        rts                                                 ; Return early if the types differ
    
@same_types:
        cmp     #TYPE_STRING            ; Is it a string?
        beq     compare_string_values   ; Yes
        lda     #>(fcmp-1)
        ldx     #<(fcmp-1)

; Fall through

; Take the two values from the top of the stack and invoke a binary operator.
; The operator handler address -1 is passed in XA (note least-significant byte is in X).
; Given an expression like 3/2, we will push 3 onto the stack, then 2, so 2 is at top of stack, and therefore the
; value we pop second goes into FP0, and the value we pop first is the argument.

call_binary_operator:
        phax                            ; Push operator handler address -1 onto the stack so we can RTS to it
        lda     #TYPE_NUMBER            ; Make sure that the first value is a number
        jsr     stack_free_value_with_type
        bcs     @error                  ; Type didn't match
        txa                             ; Original value of stack_pos, returned in X
        pha                             ; Save on stack
        jsr     pop_fp0                 ; Second value into FP0
        pla                             ; Get stack address of first value
        ldy     #>stack                 ; Stack page
        bcc     @done                   ; If pop_fp0 succeeded them jump straight to RTS
@error:
        pla                             ; Remove the operator handler address from the stack
        pla
@done:
        rts                             ; If PLAs not skipped, this does JMP to the operator handler, else return

; Invokes a binary operator and pushes the result back.

call_binary_operator_push:
        jsr     call_binary_operator
        bcc     push_fp0                ; If successful then push FP0 back, else fail
        rts

unary_op_minus:
        jsr     pop_fp0                 ; Get value at top of stack
        bcs     @error
        jsr     fneg                    ; Negate it
        jmp     push_fp0                ; Return to stack

@error:
        rts

unary_op_not:
        jsr     pop_fp0                 ; Get value
        bcs     @error
        jsr     fp0_is_zero
        bne     push_value_0            ; Value was not zero so we should return 0
        beq     push_value_1

@error:
        rts

; Push the value in FP0 onto the value stack.
; FP0 = the value to push
; Returns carry clear if the push was successful, or carry set if there was no room on the stack.
; DE SAFE

push_value_0:
        jsr     clear_fp0
        jmp     push_fp0

push_value_1:
        lday    #fp_one
        jsr     load_fp0

push_fp0:
        jsr     stack_alloc_value       ; Returns with A set to the offset
        bcs     @done                   ; Fail if overflow
        tay                             ; Stack offset into Y
        lda     #TYPE_NUMBER            ; Assign the number type
        sta     stack+Value::type,y
        tya                             ; Low byte of store address
        ldy     #>stack                 ; Stack page
        jsr     store_fp0               ; Store FP0 in the AY address
        clc                             ; Signal success
@done:
        rts

; Pops a value from the stack into an FP register.
; DE SAFE

.assert TYPE_NUMBER = $00, error

pop_fp0:
        lda     #TYPE_NUMBER            ; Make sure it's a number
        jsr     stack_free_value_with_type
        bcs     @error                  ; Wrong type
        txa                             ; Original stack position into A to use as low byte of pointer
        ldy     #>stack                 ; Stack page
        jsr     load_fp0                ; Load value into FP0
        clc                             ; Success
@error:
        rts

; Pushes the string in AX onto the stack.
; Returns carry clear on success, carry set on failure.
; DE SAFE

push_string:
        stax    BC                      ; Store string address in BC
        jsr     stack_alloc_value
        bcs     @error   
        tay
        lda     #TYPE_STRING            ; Assign the string type
        sta     stack+Value::type,y
        lda     B                       ; Recover low byte of string address
        sta     stack+Value::string_value_ptr,y     ; Save low and high byte of string address
        lda     C                       ; High byte
        sta     stack+Value::string_value_ptr+1,y   ; Carry still clear for return
@error:
        rts

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
        bcs     @done                   ; Fail if stack has stack is grown too low
        eor     #$FF                    ; It's already 1 less than we want so inverting gives two's complement
        sta     stack_pos               ; Update the stack pointer
@done:
        rts

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
; On error, carry set will be set.
; Y SAFE, BC SAFE, DE SAFE

stack_free_value_with_type:
        ldx     stack_pos               ; Get stack pointer
        cmp     stack+Value::type,x     ; Test the type
        beq     stack_free_value        ; Type check succeeded so remove value from stack
        sec                             ; Return error
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
        bcs     @error
        jsr     truncate_fp_to_int
        stax    DE                      ; Store returned value in DE
        jsr     pop_fp0
        bcs     @error
        jsr     truncate_fp_to_int
@error:
        rts                             ; Return with value in DE
