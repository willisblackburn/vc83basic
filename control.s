.include "macros.inc"
.include "basic.inc"

.zeropage

; Current position in the control stack
csp: .res 1

.bss

.assert .sizeof(Control) <= CONTROL_SIZE, error

; Stack for handling GOSUB, RETURN, and FOR
control_stack: .res CONTROL_STACK_DEPTH * CONTROL_SIZE

.code

; GOTO statement:

exec_goto:
        jsr     decode_number           ; Go get the line number
        jsr     find_line               ; Find the program line
        rts                             ; Either next_line_ptr is set or carry (error) is set

; GOSUB statement:

exec_gosub:
        jsr     push_next_line_ptr      ; Set up control stack
        bcs     @done                   ; If csp was out of range
        jsr     decode_number           ; GOSUB line number
        jsr     find_line               ; Find the line
        bcs     @done
        inc     csp                     ; Success, so increment the control stack pointer
@done:
        rts

; RETURN statement:

exec_return:
        sec                             ; Set carry so can return error if csp = 0
        lda     csp
        beq     @done
        dec     csp
        jsr     get_control_stack_index ; Set X to control stack index; clears carry
        lda     control_stack+Control::next_line_ptr,x
        sta     next_line_ptr           ; Restore next_line_ptr value
        lda     control_stack+Control::next_line_ptr+1,x
        sta     next_line_ptr+1
@done:
        rts

; FOR statement:

exec_for:
        jsr     decode_variable         ; Get the variable
        pha                             ; Save on the stack
        jsr     set_variable_value_ptr  ; Use the variable to set variable_value_ptr
        jsr     evaluate_expression     ; Start value
        jsr     pop_value               ; Get the evaluated value
        jsr     set_variable_value      ; Initialize the variable
        jsr     evaluate_expression     ; End value
        jsr     pop_value               ; Get the evaluated value
        stax    BC                      ; Store the end value into BC
        jsr     push_next_line_ptr      ; Set up control stack; X is now the control stack index
        pla                             ; Get the variable from the stack before the branch
        bcs     @done                   ; If csp was out of range
        sta     control_stack+Control::variable,x   ; Store variable
        lda     B
        sta     control_stack+Control::end_value,x
        lda     C
        sta     control_stack+Control::end_value+1,x
        lda     #1                      ; Set step value to 1
        sta     control_stack+Control::step_value,x
        lda     #0                      ; High byte is 0
        sta     control_stack+Control::step_value+1,x
        inc     csp                     ; Success, so increment the control stack pointer
@done:
        rts

; NEXT statement:

exec_next:
        jsr     decode_variable         ; Get the variable
        sta     B                       ; Store it
        jsr     set_variable_value_ptr  ; Use the variable to set variable_value_ptr
        ldx     csp                     ; Load stack position
        beq     @error                  ; If 0 then fail
        dex                             ; Decrement it (but don't update csp yet)
        txa
        jsr     get_control_stack_index_a   ; Calculate control stack index for decremented position
        lda     control_stack+Control::variable,x   ; Get the variable
        cmp     B                       ; Is it the one we saved earlier?
        bne     @error                  ; If not then fail
        ldy     #0                      ; Use Y to index variable value
        clc
        lda     control_stack+Control::step_value,x   ; Get low byte of step value
        adc     (variable_value_ptr),y  ; Add to variable value
        sta     (variable_value_ptr),y  ; Store back
        sta     C                       ; Store in C also, to use in comparison
        iny                             ; Increment to add high byte
        lda     control_stack+Control::step_value+1,x 
        adc     (variable_value_ptr),y
        sta     (variable_value_ptr),y
        cmp     control_stack+Control::end_value+1,x    ; Compare high byte to end value
        bcc     @return_to_for          ; Value high byte < end, keep going
        bne     @pop_for                ; Value high byte > end, stop
        lda     C                       ; Load value low byte back from C
        cmp     control_stack+Control::end_value,x      ; Compare low byte to end value
        bcc     @return_to_for          ; Value low byte < end, keep going
        beq     @return_to_for          ; Also keep going if values are equal
@pop_for:
        dec     csp                     ; Discard the FOR from the control stack and keep going
        clc                             ; Signal success
        rts

@error:
        sec                             ; Signal error
        rts

@return_to_for:
        lda     control_stack+Control::next_line_ptr,x
        sta     next_line_ptr           ; Restore next_line_ptr value
        lda     control_stack+Control::next_line_ptr+1,x
        sta     next_line_ptr+1
        clc                             ; Signal success
        rts                            

; Common function that sets the X register to the correct offset for the csp value in A.
; If csp is < CONTROL_SIZE, returns carry clear and X set to the offset, or returns carry set if csp is out of range.
; A = csp value
; Y SAFE, BC SAFE, DE SAFE

; TODO: probably want to return in Y since we use X a lot already

; The actual size has to match the shift logic.
.assert CONTROL_SIZE = 16, error

get_control_stack_index:
        lda     csp                     
get_control_stack_index_a:
        cmp     #CONTROL_SIZE
        beq     @done                   ; Return with carry set
        asl     A                       ; Multiply stack postion by 16
        asl     A
        asl     A
        asl     A
        tax
@done:
        rts

; Add an entry onto the control stack and set the next_line_ptr field.
; Reflects carry return from get_control_stack_index. On success, X is still the control stack index.
; Y SAFE, BC SAFE, DE SAFE

push_next_line_ptr:
        jsr     get_control_stack_index ; Set X to control stack index
        bcs     @done                   ; If csp was out of range
        lda     next_line_ptr           ; Store next_line_ptr on control stack
        sta     control_stack+Control::next_line_ptr,x
        lda     next_line_ptr+1
        sta     control_stack+Control::next_line_ptr+1,x
@done:
        rts


