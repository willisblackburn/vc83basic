.include "macros.inc"
.include "basic.inc"

.zeropage

; The number we're dispatching in an ON...GOTO/GOSUB statement
on_value: .res 1

; The handler vector for ON...GOTO/GOSUB
on_handler: .res 2

.code

; Logic depends on TOKEN_NO_VALUE being zero
.assert TOKEN_NO_VALUE = 0, error

; GOTO statement:

exec_goto:
        jsr     decode_number           ; Go get the line number
exec_goto_ax:
        jsr     find_line               ; Find the program line
        rts                             ; Either next_line_ptr is set or carry (error) is set

; ON...GOTO statement:

exec_on_goto:
        ldax    #exec_goto_ax           ; Handler address
        jmp     exec_on

; GOSUB statement:

exec_gosub:
        jsr     decode_number           ; GOSUB line number
exec_gosub_ax:
        stax    BC                      ; Temporarily store the line number in BC
        jsr     push_next_line_ptr      ; Save return address
        bcs     @done                   ; Stack overflow
        lda     #TOKEN_VAR              ; Set variable field to an invalid variable
        sta     primary_stack+Control::variable,x
        ldax    BC                      ; Reload line number
        jsr     find_line               ; Find the line
        bcs     @done
@done:
        rts

; ON...GOSUB statement:

exec_on_gosub:
        ldax    #exec_gosub_ax           ; Handler address

; Fall through

exec_on:
        stax    on_handler              ; Store the handler address
        jsr     evaluate_expression     ; Evaluate the "ON" expression
        jsr     pop_value
        sta     on_value
        txa                             ; Check the high byte
        bne     @error                  ; If high byte is set then value is out of range (either <0 or >255)
@loop:
        ldy     lp
        lda     (line_ptr),y            ; Peek at next character
        beq     @not_found              ; If it's TOKEN_NO_VLAUE, nothing matched; continue
        jsr     decode_number           ; Get the next line number into AX
        dec     on_value                ; Decrement the "ON" value
        bne     @loop                   ; If not zero then keep looking
        jmp     (on_handler)            ; Jump to whatever handler was passed in

@not_found:
        clc
        rts

@error:
        sec
        rts

; RETURN statement:

exec_return:
        jsr     exec_pop                ; RETURN is just POP except we do something with the popped value
        bcs     @done
        lda     primary_stack+Control::variable,x   ; Get the variable
        cmp     #TOKEN_VAR              ; Make sure it's the invalid value that signals a GOSUB
        sec                             ; If we take this next branch then carry will be set to signal error
        bne     @done                   ; Variable was not GOSUB signal
        lda     primary_stack+Control::next_line_ptr,x
        sta     next_line_ptr           ; Restore next_line_ptr value
        lda     primary_stack+Control::next_line_ptr+1,x
        sta     next_line_ptr+1
        clc                             ; Signal success
@done:
        rts

; Add an entry onto the primary stack and set the next_line_ptr field.
; Reflects carry return from stack_alloc. On success, X is still the stack pointer.
; Y SAFE, BC SAFE, DE SAFE

push_next_line_ptr:
        lda     #.sizeof(Control)       ; Allocate this much space for the control record
        jsr     stack_alloc
        bcs     @done                   ; Stack overflow
        lda     next_line_ptr           ; Store next_line_ptr on stack
        sta     primary_stack+Control::next_line_ptr,x
        lda     next_line_ptr+1
        sta     primary_stack+Control::next_line_ptr+1,x
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
        jsr     push_next_line_ptr      ; Push return address; X is now the stack pointer
        pla                             ; Get the variable from the stack before the branch
        bcs     @done                   ; Stack overflow
        sta     primary_stack+Control::variable,x   ; Store variable
        lda     B
        sta     primary_stack+Control::end_value,x
        lda     C
        sta     primary_stack+Control::end_value+1,x
        lda     #1                      ; Set step value to 1
        sta     primary_stack+Control::step_value,x
        lda     #0                      ; High byte is 0
        sta     primary_stack+Control::step_value+1,x
@done:
        rts

; NEXT statement:

exec_next:
        jsr     decode_variable         ; Get the variable
        sta     B                       ; Store it
        jsr     set_variable_value_ptr  ; Use the variable to set variable_value_ptr
        ldx     psp                     ; Load stack position
        cpx     #PRIMARY_STACK_SIZE     ; Check if stack empty
        beq     @error                  ; If so then fail
        lda     primary_stack+Control::variable,x   ; Get the variable
        cmp     B                       ; Is it the one we saved earlier?
        bne     @error                  ; If not then fail
        ldy     #0                      ; Use Y to index variable value
        clc
        lda     primary_stack+Control::step_value,x   ; Get low byte of step value
        adc     (variable_value_ptr),y  ; Add to variable value
        sta     (variable_value_ptr),y  ; Store back
        sta     C                       ; Store in C also, to use in comparison
        iny                             ; Increment to add high byte
        lda     primary_stack+Control::step_value+1,x 
        adc     (variable_value_ptr),y
        sta     (variable_value_ptr),y
        cmp     primary_stack+Control::end_value+1,x    ; Compare high byte to end value
        bcc     @return_to_for          ; Value high byte < end, keep going
        bne     exec_pop                ; Value high byte > end, stop
        lda     C                       ; Load value low byte back from C
        cmp     primary_stack+Control::end_value,x      ; Compare low byte to end value
        bcc     @return_to_for          ; Value low byte < end, keep going
        bne     exec_pop                ; Value high byte > end, stop
@return_to_for:
        lda     primary_stack+Control::next_line_ptr,x
        sta     next_line_ptr           ; Restore next_line_ptr value
        lda     primary_stack+Control::next_line_ptr+1,x
        sta     next_line_ptr+1
        clc                             ; Signal success
        rts                            

@error:
        sec                             ; Signal error
        rts

; POP statement:
; Returns with the popped stack pointer still in X so caller can use.

exec_pop:
        sec                             ; Set carry so can return error if csp = 0
        ldx     psp                     ; Check stack pointer
        cpx     #PRIMARY_STACK_SIZE     ; Stack empty?
        beq     @done                   ; Yep
        lda     #.sizeof(Control)       ; Free the control record
        jsr     stack_free
        clc                             ; Success
@done:
        rts
