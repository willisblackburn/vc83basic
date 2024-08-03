.include "macros.inc"
.include "basic.inc"

; Logic depends on TOKEN_NO_VALUE being zero
.assert TOKEN_NO_VALUE = 0, error

; GOTO statement:

exec_goto:
        jsr     decode_number           ; Go get the line number
exec_goto_line_number:
        jsr     find_line               ; Find the program line
        rts                             ; Either next_line_ptr is set or carry (error) is set

; ON...GOTO statement:

exec_on_goto:
        ldax    #exec_goto_line_number  ; Handler address
        jmp     exec_on

; GOSUB statement:

exec_gosub:
        jsr     decode_number           ; GOSUB line number
exec_gosub_line_number:
        stax    line_number             ; Store the line number before calling find_line
        jsr     push_next_line_ptr      ; Save return address
        bcs     @done                   ; Stack overflow
        lda     #0                      ; Set variable field to an invalid pointer
        sta     primary_stack+Control::variable_name_ptr+1,x
        jsr     find_line_2             ; Find the line (already in line_number)
        bcs     @done
@done:
        rts

; ON...GOSUB statement:

exec_on_gosub:
        ldax    #exec_gosub_line_number ; Handler address

; Fall through

exec_on:
        stax    on_handler              ; Store the handler address
        jsr     evaluate_expression     ; Evaluate the "ON" expression
        jsr     pop_value
        sta     on_value
        txa                             ; Check the high byte
        bne     @error                  ; If high byte is set then value is out of range (either <0 or >255)
@loop:
        ldy     line_pos
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
        sec                             ; If we take this next branch then carry will be set to signal error
        lda     primary_stack+Control::variable_name_ptr+1,x    ; Check if high byte of variable name pointer is 0
        bne     @done                   ; Variable was not GOSUB signal
        lda     primary_stack+Control::next_line_ptr,x
        sta     next_line_ptr           ; Restore next_line_ptr value
        lda     primary_stack+Control::next_line_ptr+1,x
        sta     next_line_ptr+1
        clc                             ; Signal success
@done:
        rts

; FOR statement:

exec_for:
        jsr     push_next_line_ptr      ; Save return address
        bcs     @error                  ; Stack overflow
        jsr     decode_name             ; Get the name (now in name_ptr)
        ldx     psp                     ; Get stack pointer to store name
        lda     name_ptr                ; Store pointer to variable name
        sta     primary_stack+Control::variable_name_ptr,x
        lda     name_ptr+1
        sta     primary_stack+Control::variable_name_ptr+1,x
        jsr     find_or_initialize_variable
        bcs     @error                  ; No space for variable
        mvax    record_ptr, variable_ptr
        jsr     evaluate_expression     ; Start value (may clobber name_ptr)
        jsr     pop_value
        jsr     assign_variable         ; Assign starting value
        jsr     evaluate_expression     ; End value
        jsr     pop_value               ; Get the evaluated value
        ldy     psp                     ; Get stack pointer to store end value
        sta     primary_stack+Control::end_value,y
        txa
        sta     primary_stack+Control::end_value+1,y
        lda     #1                      ; Set step value to 1
        sta     primary_stack+Control::step_value,y
        lda     #0                      ; High byte is 0
        sta     primary_stack+Control::step_value+1,y
@error:
        rts

; NEXT statement:

exec_next:
        jsr     decode_name             ; Sets name_ptr
        ldx     psp                     ; Load stack position
        cpx     #PRIMARY_STACK_SIZE     ; Check if stack empty
        beq     @error                  ; If so then fail
        sec                             ; Set carry in case this next check fails
        lda     primary_stack+Control::variable_name_ptr,x  ; Point record_ptr to name at top of control stack
        sta     record_ptr
        lda     primary_stack+Control::variable_name_ptr+1,x
        beq     @error                  ; If it was zero then top of stack is GOSUB not FOR
        sta     record_ptr+1
        jsr     match_name              ; Make sure it's the right name
        bcs     @error
        jsr     find_or_initialize_variable     ; Should not fail since variable is already initialized from FOR
        bcs     @error                  ; Just in case...
        ldx     psp                     ; Load stack position
        ldy     #0                      ; Use Y to index variable value
        clc
        lda     primary_stack+Control::step_value,x   ; Get low byte of step value
        adc     (record_ptr),y          ; Add to variable value
        sta     (record_ptr),y          ; Store back
        sta     C                       ; Store in C also, to use in comparison
        iny                             ; Increment to add high byte
        lda     primary_stack+Control::step_value+1,x 
        adc     (record_ptr),y
        sta     (record_ptr),y
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

exec_if:
        jsr     evaluate_expression     ; Evaluate the expression
        jsr     pop_value
        sta     B                       ; Store low byte of result in B
        txa                             ; Transfer high byte into X
        ora     B                       ; Or the high and low bytes together
        beq     @done                   ; If zero then don't execute the THEN
        jsr     dispatch_statement      ; Otherwise execute the THEN
@done:
        clc
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
