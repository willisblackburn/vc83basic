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
        jsr     decode_int              ; Go get the line number
exec_goto_ax:
        jsr     find_line               ; Find the program line
        rts                             ; Either next_line_ptr is set or carry (error) is set

; ON...GOTO statement:

exec_on_goto:
        ldax    #exec_goto_ax           ; Handler address
        jmp     exec_on

; GOSUB statement:

exec_gosub:
        jsr     decode_int              ; GOSUB line number
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
        jsr     pop_fp0
        jsr     truncate_fp_to_int      ; FP0 -> integer in AX
        sta     on_value
        sec                             ; Set carry in case this next check fails
        txa                             ; Check if >=256 or negative
        bne     @error                  ; Yes, go check the values
@loop:
        ldy     lp
        lda     (line_ptr),y            ; Peek at next character
        beq     @not_found              ; If it's TOKEN_NO_VALUE, nothing matched; continue
        jsr     decode_int              ; Get the next line number into AX
        dec     on_value                ; Decrement the "ON" value
        bne     @loop                   ; If not zero then keep looking
        jmp     (on_handler)            ; Jump to whatever handler was passed in

@not_found:
        clc
@error:
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
; Reflects carry return from stack_alloc. On success, A is still the stack pointer.
; Y SAFE, BC SAFE, DE SAFE

push_next_line_ptr:
        lda     #.sizeof(Control)       ; Allocate this much space for the control record
        jsr     stack_alloc
        bcs     @done                   ; Stack overflow
        tax                             ; Stack pointer into X to use as index
        lda     next_line_ptr           ; Store next_line_ptr on stack
        sta     primary_stack+Control::next_line_ptr,x
        lda     next_line_ptr+1
        sta     primary_stack+Control::next_line_ptr+1,x
        txa                             ; Move stack pointer back to A
@done:
        rts

; FOR statement:

exec_for:
        jsr     decode_variable         ; Get the variable
        pha                             ; Save on the stack twice
        pha
        jsr     evaluate_expression     ; Start value
        pla                             ; Get variable back
        jsr     pop_variable            ; Pop value from stack into variable
        jsr     evaluate_expression     ; End value
        jsr     pop_fp0                 ; Get the evaluated value
        jsr     push_next_line_ptr      ; Push return address; X is now the stack pointer
        pla                             ; Get variable again
        sta     primary_stack+Control::variable,x   ; Store it in control record
        txa                             ; Stack pointer into A
        pha                             ; Save it because we'll want it again soon
        clc
        adc     #Control::end_value     ; Add the offset of the end value
        ldy     #>primary_stack         ; Segment of stack
        jsr     store_fp0               ; Store FP0 there
        lday    #fp_one
        jsr     load_fp0
        pla                             ; Recover stack pointer
        clc
        adc     #Control::step_value    ; Add the offset of the step value
        ldy     #>primary_stack
        jsr     store_fp0               ; Store the step value
        clc
        rts

; NEXT statement:

exec_next:
        jsr     decode_variable         ; Get the variable
        pha                             ; Save it on stack twice
        pha
        ldx     psp                     ; Load stack position
        cpx     #PRIMARY_STACK_SIZE     ; Check if stack empty
        beq     @error                  ; If so then fail
        pla                             ; Get the variable back
        cmp     primary_stack+Control::variable,x   ; Is it the right one?
        bne     @error2                 ; If not then fail
        jsr     push_variable           ; Otherwise get the value and push onto the stack
        jsr     pop_fp0                 ; Move it to FP0 to prepare for fadd
        lda     psp                     ; Get stack position again
        clc
        adc     #Control::step_value    ; Add offset of step value to stack pointer
        ldy     #>primary_stack         ; Segment of stack
        ldx     #FP1                    ; Load step into FP1
        jsr     load_fpx
        jsr     fadd                    ; Add the values
        jsr     push_fp0                ; Push back onto stack
        pla                             ; Get the variable back
        jsr     pop_variable            ; Back into variable
        lda     psp                     ; Get stack position again
        clc
        adc     #Control::end_value     ; Calculate address of end value
        ldy     #>primary_stack
        ldx     #FP1                    ; Load end value into FP1
        jsr     load_fpx        
        jsr     fcmp                    ; Compare the current value with the end value
        bcc     @return_to_for          ; Had to borrow so end value > start value
        bne     exec_pop                ; If not equal then end value < start value; terminate FOR
@return_to_for:
        ldx     psp                     ; Get stack pointer once again
        lda     primary_stack+Control::next_line_ptr,x
        sta     next_line_ptr           ; Restore next_line_ptr value
        lda     primary_stack+Control::next_line_ptr+1,x
        sta     next_line_ptr+1
        clc                             ; Signal success
        rts                            

@error:
        pla                             ; Get rid of variable on stack
@error2:
        pla                             ; Second copy of variable
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
        jsr     pop_fp0
        jsr     fp0_is_zero             ; Check if zero
        beq     @done                   ; If zero then don't execute the THEN
        jsr     dispatch_statement      ; Otherwise execute the THEN
@done:
        clc
        rts
