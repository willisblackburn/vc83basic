.include "macros.inc"
.include "basic.inc"

; stack must be page-aligned
.assert <stack = 0, error

; GOTO statement:

exec_goto:
        jsr     get_line_number         ; Go get the line number
exec_goto_line_number:
        jsr     find_line               ; Find the program line
        rts                             ; Either next_line_ptr is set or carry (error) is set

; ON...GOTO statement:

exec_on_goto:
        ldax    #exec_goto_line_number  ; Handler address
        jmp     exec_on

; GOSUB statement:

exec_gosub:
        jsr     get_line_number         ; GOSUB line number
exec_gosub_line_number:
        stax    line_number             ; Store the line number before calling find_line
        jsr     push_next_line_ptr      ; Save return address
        bcs     @done                   ; Stack overflow
        lda     #0                      ; Set variable field to an invalid pointer
        sta     stack+Control::variable_name_ptr+1,x
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
        inc     line_pos                ; Skip past the terminator
        jsr     pop_fp0
        jsr     truncate_fp_to_int      ; FP0 -> integer in AX
        sta     on_value
        sec                             ; Set carry in case this next check fails
        txa                             ; Check the high byte
        bne     @error                  ; If high byte is set then value is out of range (either <0 or >255)
@loop:
        dec     on_value                ; Decrease value sought by 1
        bmi     @zero                   ; If it went negative then it was originally 0
        beq     @found                  ; It was found
        ldy     line_pos                ; Otherwise advance to the next ','
@next_byte:
        lda     (line_ptr),y
        beq     @error                  ; Found the terminator instead
        iny
        cmp     #','
        bne     @next_byte
        sty     line_pos                ; Update line_pos with the position after the next ','
        beq     @loop                   ; Unconditional

@found:
        jsr     get_line_number         ; Get the next line number into AX
        jmp     (on_handler)            ; Jump to whatever handler was passed in

@zero:
        clc
@error:
        rts

; RETURN statement:

exec_return:
        jsr     exec_pop                ; RETURN is just POP except we do something with the popped value
        bcs     @done
        sec                             ; If we take this next branch then carry will be set to signal error
        lda     stack+Control::variable_name_ptr+1,x    ; Check if high byte of variable name pointer is 0
        bne     @done                   ; Variable was not GOSUB signal
        lda     stack+Control::next_line_ptr,x
        sta     next_line_ptr           ; Restore next_line_ptr value
        lda     stack+Control::next_line_ptr+1,x
        sta     next_line_ptr+1
        lda     stack+Control::next_line_pos,x
        sta     next_line_pos           ; Restore next_line_pos value
        clc                             ; Signal success
@done:
        rts

; FOR statement:

exec_for:
        jsr     push_next_line_ptr      ; Save return address
        bcs     @error                  ; Stack overflow
        jsr     decode_name             ; Get the name (now in decode_name_ptr)
        inc     line_pos                ; Skip terminator following name
        ldx     stack_pos               ; Get stack pointer to store name
        lda     decode_name_ptr         ; Store pointer to variable name
        sta     stack+Control::variable_name_ptr,x
        lda     decode_name_ptr+1
        sta     stack+Control::variable_name_ptr+1,x
        jsr     evaluate_expression     ; Start value (may clobber decode_name_ptr)
        inc     line_pos                ; Skip terminator
        bcs     @error
        jsr     find_or_add_variable
        bcs     @error
        jsr     assign_variable
        jsr     evaluate_expression     ; End value
        inc     line_pos                ; Skip terminator
        bcs     @error
        jsr     pop_fp0                 ; Get the evaluated value
        bcs     @error
        lda     stack_pos               ; Stack pointer
        adc     #Control::end_value     ; Add the offset of the end value
        ldy     #>stack                 ; Stack page
        jsr     store_fp0               ; Store FP0 there
        lday    #fp_one
        jsr     load_fp0
        lda     stack_pos               ; Stack pointer again
        clc
        adc     #Control::step_value    ; Add the offset of the step value
        ldy     #>stack
        jsr     store_fp0               ; Store the step value
        clc
@error:
        rts

; NEXT statement:

exec_next:

; Decode the variable name and see if it matches the one at the top of the stack.

        jsr     decode_name             ; Sets decode_name_ptr
        ldx     stack_pos               ; Load stack position
        cpx     #PRIMARY_STACK_SIZE     ; Check if stack empty
        sec                             ; Set carry in case one of these two BEQs fails
        beq     @error                  ; If so then fail
        lda     stack+Control::variable_name_ptr,x  ; Point name_ptr to name at top of control stack
        sta     name_ptr
        lda     stack+Control::variable_name_ptr+1,x
        beq     @error                  ; If it was zero then top of stack is GOSUB not FOR
        sta     name_ptr+1
        jsr     match_name              ; Make sure it's the right name
        bcs     @error
        jsr     evaluate_decoded_variable   ; Continue with evaluation of variable decoded above
        bcs     @error
        jsr     pop_fp0                 ; Variable value is now in FP0
        bcs     @error
        lda     stack_pos               ; Get stack position again
        adc     #Control::step_value    ; Add offset of step value to stack pointer (carry will be clear)
        ldy     #>stack                 ; Stack page
        jsr     fadd                    ; Add the step value to the variable value from before
        jsr     push_fp0                ; Push back onto stack
        jsr     assign_variable         ; Assign stack value to name_ptr set up earlier
        lda     stack_pos               ; Get stack position again
        clc
        adc     #Control::end_value     ; Calculate address of end value (carry will be clear)
        ldy     #>stack
        jsr     fcmp                    ; Compare the current value (still in FP0) with the end value
        bcc     @return_to_for          ; Current value < end value so continue
        bne     exec_pop                ; If not equal then value > end value so stop; else continue
@return_to_for:
        ldx     stack_pos               ; Get stack pointer once again
        lda     stack+Control::next_line_ptr,x
        sta     next_line_ptr           ; Restore next_line_ptr value
        lda     stack+Control::next_line_ptr+1,x
        sta     next_line_ptr+1
        lda     stack+Control::next_line_pos,x
        sta     next_line_pos           ; Restore next_line_pos value
        clc                             ; Signal success
@error:
        rts                            

; POP statement:
; Returns with the popped stack pointer still in X so caller can use.

exec_pop:
        sec                             ; Set carry so can return error if csp = 0
        ldx     stack_pos               ; Check stack pointer
        cpx     #PRIMARY_STACK_SIZE     ; Stack empty?
        beq     @done                   ; Yep
        lda     #.sizeof(Control)       ; Free the control record
        jsr     stack_free
        clc                             ; Success
@done:
        rts

exec_if:
        jsr     evaluate_expression     ; Evaluate the expression
        inc     line_pos                ; Skip terminator
        jsr     pop_fp0
        lda     FP0e                    ; Check if zero
        beq     @next_line              ; If zero then don't execute the THEN or any other statements on this line
        jsr     dispatch_statement      ; Otherwise execute the THEN
        clc
        rts

@next_line:
        jsr     advance_next_line_ptr   ; Unconditionally go to the next line
        clc
        rts

push_next_line_ptr:
        lda     #.sizeof(Control)       ; Allocate this much space for the control record
        jsr     stack_alloc
        bcs     @done                   ; Stack overflow
        tax                             ; Stack pointer into X to use as index
        lda     next_line_ptr           ; Store next_line_ptr on stack
        sta     stack+Control::next_line_ptr,x
        lda     next_line_ptr+1
        sta     stack+Control::next_line_ptr+1,x
        lda     next_line_pos
        sta     stack+Control::next_line_pos,x
        txa                             ; Move stack pointer back to A
@done:
        rts

get_line_number:
        jsr     decode_number
        jmp     truncate_fp_to_int
