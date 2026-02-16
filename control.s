.include "macros.inc"
.include "basic.inc"

; stack must be page-aligned
.assert <stack = 0, error

; We use type to distinguish between Value and Control on the stack, so make sure they're at the same offset.
.assert Control::type = Value::type, error

; GOTO statement:

exec_goto:
        jsr     get_line_number         ; Go get the line number
exec_goto_line_number:
        jmp     get_line                ; Find the line; either next_line_ptr is set or raises exception

; ON...GOTO statement:

exec_on_goto:
        ldax    #exec_goto_line_number  ; Handler address
        jmp     exec_on

; GOSUB statement:

exec_gosub:
        jsr     get_line_number         ; GOSUB line number
exec_gosub_line_number:
        phax                            ; Save line number
        jsr     push_next_line_ptr      ; Save return address
        lda     #0                      ; Set variable field to an invalid pointer
        sta     stack+Control::variable_name_ptr+1,x
        plax                            ; Recover line number
        jmp     get_line                ; Find the line; either next_line_ptr is set or raises exception

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
        sta     B
        sec                             ; Set carry in case this next check fails
        txa                             ; Check the high byte
        bne     @out_of_range           ; If high byte is set then value is out of range (either <0 or >255)
@loop:
        dec     B                       ; Decrease value sought by 1
        bmi     @zero                   ; If it went negative then it was originally 0
        beq     @found                  ; It was found
        ldy     line_pos                ; Otherwise advance to the next ','
@next_byte:
        lda     (line_ptr),y
        beq     @out_of_range           ; Found the terminator instead
        iny
        cmp     #','
        bne     @next_byte
        sty     line_pos                ; Update line_pos with the position after the next ','
        beq     @loop                   ; Unconditional

@found:
        jsr     get_line_number         ; Get the next line number into AX
        jmp     (on_handler)            ; Jump to whatever handler was passed in

@zero:
        rts

@out_of_range:
        raise   ERR_OUT_OF_RANGE

; RETURN statement:

exec_return:
        ldx     stack_pos               ; Check stack pointer
        cpx     #PRIMARY_STACK_SIZE     ; Stack empty?
        beq     @return_without_gosub
        lda     stack+Control::variable_name_ptr+1,x    ; Check if high byte of variable name pointer is 0
        bne     @return_without_gosub   ; Variable was not GOSUB signal
        lda     stack+Control::next_line_ptr,x
        sta     next_line_ptr           ; Restore next_line_ptr value
        lda     stack+Control::next_line_ptr+1,x
        sta     next_line_ptr+1
        lda     stack+Control::next_line_pos,x
        sta     next_line_pos           ; Restore next_line_pos value
        jmp     exec_pop_2

@return_without_gosub:
        raise   ERR_RETURN_WITHOUT_GOSUB

; FOR statement:

.assert TYPE_NUMBER = $00, error

exec_for:
        jsr     push_next_line_ptr      ; Save return address
        jsr     decode_name             ; Get the name (now in decode_name_ptr)
        sec                             ; Set carry for error return if type check goes wrong
        lda     decode_name_type        ; No string variables please
        bne     @invalid_variable
        lda     decode_name_arity       ; Or arrays
        bmi     @invalid_variable
        inc     line_pos                ; Skip terminator following name
        ldx     stack_pos               ; Get stack pointer to store name
        lda     decode_name_ptr         ; Store pointer to variable name
        sta     stack+Control::variable_name_ptr,x
        lda     decode_name_ptr+1
        sta     stack+Control::variable_name_ptr+1,x
        jsr     evaluate_expression     ; Start value (may clobber decode_name_ptr)
        inc     line_pos                ; Skip terminator
        jsr     find_or_add_variable
        jsr     assign_variable
        jsr     evaluate_expression     ; End value
        inc     line_pos                ; Skip terminator
        jsr     pop_fp0                 ; Get the evaluated value
        lda     stack_pos               ; Stack pointer
        adc     #Control::end_value     ; Add the offset of the end value; carry is clear
        ldy     #>stack                 ; Stack page
        jsr     store_fp0               ; Store FP0 there
        lday    #fp_one
        jsr     load_fp0
        lda     stack_pos               ; Stack pointer again
        clc
        adc     #Control::step_value    ; Add the offset of the step value
        ldy     #>stack
        jsr     store_fp0               ; Store the step value
        rts

@invalid_variable:
        raise   ERR_INVALID_VARIABLE

; NEXT statement:

exec_next:

; Decode the variable name and see if it matches the one at the top of the stack.

        jsr     decode_name             ; Sets decode_name_ptr
        ldx     stack_pos               ; Load stack position
        cpx     #PRIMARY_STACK_SIZE     ; Check if stack empty
        beq     @next_without_for       ; If so then fail
        lda     stack+Control::variable_name_ptr,x  ; Point name_ptr to name at top of control stack
        sta     name_ptr
        lda     stack+Control::variable_name_ptr+1,x
        beq     @next_without_for       ; If it was zero then top of stack is GOSUB not FOR
        sta     name_ptr+1
        jsr     match_name              ; Make sure it's the right name
        bcs     @invalid_variable
        jsr     evaluate_decoded_variable   ; Continue with evaluation of variable decoded above
        bcs     @next_without_for
        jsr     pop_fp0                 ; Variable value is now in FP0
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
        bne     exec_pop_2              ; If not equal then value > end value so stop; else continue
@return_to_for:
        ldx     stack_pos               ; Get stack pointer once again
        lda     stack+Control::next_line_ptr,x
        sta     next_line_ptr           ; Restore next_line_ptr value
        lda     stack+Control::next_line_ptr+1,x
        sta     next_line_ptr+1
        lda     stack+Control::next_line_pos,x
        sta     next_line_pos           ; Restore next_line_pos value
        clc                             ; Signal success
        rts

@next_without_for:
        raise   ERR_NEXT_WITHOUT_FOR                            

@invalid_variable:
        raise   ERR_INVALID_VARIABLE

; POP statement:
; Returns with the popped stack pointer still in X so caller can use.

exec_pop:
        ldx     stack_pos               ; Check stack pointer
        cpx     #PRIMARY_STACK_SIZE     ; Stack empty?
        raieq   ERR_STACK_EMPTY
exec_pop_2:
        lda     #.sizeof(Control)       ; Free the control record
        jmp     stack_free

exec_if:
        jsr     evaluate_expression     ; Evaluate the expression
        inc     line_pos                ; Skip terminator
        jsr     pop_fp0
        lda     FP0e                    ; Check if zero
        beq     @next_line              ; If zero then don't execute the THEN or any other statements on this line
        jmp     exec_statement          ; Otherwise execute the THEN

@next_line:
        jmp     advance_next_line_ptr   ; Unconditionally go to the next line

push_next_line_ptr:
        lda     #.sizeof(Control)       ; Allocate this much space for the control record
        jsr     stack_alloc
        tax                             ; Stack pointer into X to use as index
        lda     next_line_ptr           ; Store next_line_ptr on stack
        sta     stack+Control::next_line_ptr,x
        lda     next_line_ptr+1
        sta     stack+Control::next_line_ptr+1,x
        lda     next_line_pos
        sta     stack+Control::next_line_pos,x
        lda     #TYPE_CONTROL           ; Identify this as Control not Value
        sta     stack+Control::type,x
        txa                             ; Move stack pointer back to A
        rts

get_line_number:
        jsr     decode_number
        jmp     truncate_fp_to_int
