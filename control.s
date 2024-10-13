.include "macros.inc"
.include "basic.inc"

; Logic depends on TOKEN_NO_VALUE being zero
.assert TOKEN_NO_VALUE = 0, error

; primary_stack must be page-aligned
.assert <primary_stack = 0, error

; GOTO statement:

exec_goto:
        jsr     decode_int              ; Go get the line number
exec_goto_line_number:
        jsr     find_line               ; Find the program line
        rts                             ; Either next_line_ptr is set or carry (error) is set

; ON...GOTO statement:

exec_on_goto:
        ldax    #exec_goto_line_number  ; Handler address
        jmp     exec_on

; GOSUB statement:

exec_gosub:
        jsr     decode_int              ; GOSUB line number
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
        jsr     pop_fp0
        bcs     @error
        jsr     truncate_fp_to_int      ; FP0 -> integer in AX
        sta     on_value
        sec                             ; Set carry in case this next check fails
        txa                             ; Check the high byte
        bne     @error                  ; If high byte is set then value is out of range (either <0 or >255)
@loop:
        ldy     line_pos
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
        sec                             ; If we take this next branch then carry will be set to signal error
        lda     primary_stack+Control::variable_name_ptr+1,x    ; Check if high byte of variable name pointer is 0
        bne     @done                   ; Variable was not GOSUB signal
        lda     primary_stack+Control::next_line_ptr,x
        sta     next_line_ptr           ; Restore next_line_ptr value
        lda     primary_stack+Control::next_line_ptr+1,x
        sta     next_line_ptr+1
        lda     primary_stack+Control::next_line_pos,x
        sta     next_line_pos           ; Restore next_line_pos value
        clc                             ; Signal success
@done:
        rts

; FOR statement:

.assert TYPE_NUM = 0, error

exec_for:
        jsr     push_next_line_ptr      ; Save return address
        bcs     @error                  ; Stack overflow
        jsr     decode_name             ; Get the name (now in match_ptr)
        sec                             ; Set carry for error return if type check goes wrong
        lda     name_type               ; No string variables please
        bne     @error
        sta     variable_type           ; While we have the type in A, save in variable_type
        ldx     psp                     ; Get stack pointer to store name
        lda     match_ptr               ; Store pointer to variable name
        sta     primary_stack+Control::variable_name_ptr,x
        lda     match_ptr+1
        sta     primary_stack+Control::variable_name_ptr+1,x
        jsr     find_or_add_variable
        bcs     @error                  ; No space for variable
        mvax    node_ptr, variable_ptr
        jsr     evaluate_expression     ; Start value (may clobber match_ptr)
        jsr     assign_variable
        jsr     evaluate_expression     ; End value
        jsr     pop_fp0                 ; Get the evaluated value
        bcs     @error
        lda     psp                     ; Stack pointer
        adc     #Control::end_value     ; Add the offset of the end value; carry is clear
        ldy     #>primary_stack         ; Segment of stack
        jsr     store_fp0               ; Store FP0 there
        lday    #fp_one
        jsr     load_fp0
        lda     psp                     ; Stack pointer again
        clc
        adc     #Control::step_value    ; Add the offset of the step value
        ldy     #>primary_stack
        jsr     store_fp0               ; Store the step value
        clc
@error:
        rts

; NEXT statement:

exec_next:
        jsr     evaluate_variable       ; Evaluates the variable after next; sets match_ptr
        bcs     @error
        mvax    node_ptr, variable_ptr  ; Set up target for assign_variable later
        mva     name_type, variable_type
        jsr     pop_fp0                 ; Variable value is now in FP0
        bcs     @error
        ldx     psp                     ; Load stack position
        cpx     #PRIMARY_STACK_SIZE     ; Check if stack empty
        sec                             ; Set carry in case one of these two BEQs fails
        beq     @error                  ; If so then fail
        lda     primary_stack+Control::variable_name_ptr,x  ; Point node_ptr to name at top of control stack
        sta     node_ptr
        lda     primary_stack+Control::variable_name_ptr+1,x
        beq     @error                  ; If it was zero then top of stack is GOSUB not FOR
        sta     node_ptr+1
        jsr     match_name              ; Make sure it's the right name
        bcs     @error
        lda     psp                     ; Get stack position again
        adc     #Control::step_value    ; Add offset of step value to stack pointer (carry will be clear)
        ldy     #>primary_stack         ; Segment of stack
        ldx     #FP1                    ; Load step into FP1
        jsr     load_fpx
        jsr     fadd                    ; Add the step value to the variable value from before
        jsr     push_fp0                ; Push back onto stack
        jsr     assign_variable         ; Assign stack value to variable_ptr set up earlier
        lda     psp                     ; Get stack position again
        clc
        adc     #Control::end_value     ; Calculate address of end value (carry will be clear)
        ldy     #>primary_stack
        ldx     #FP1                    ; Load end value into FP1
        jsr     load_fpx        
        jsr     fcmp                    ; Compare the current value (still in FP0) with the end value
        bcc     @return_to_for          ; Current value < end value so continue
        bne     exec_pop                ; If not equal then value > end value so stop; else continue
@return_to_for:
        ldx     psp                     ; Get stack pointer once again
        lda     primary_stack+Control::next_line_ptr,x
        sta     next_line_ptr           ; Restore next_line_ptr value
        lda     primary_stack+Control::next_line_ptr+1,x
        sta     next_line_ptr+1
        lda     primary_stack+Control::next_line_pos,x
        sta     next_line_pos           ; Restore next_line_pos value
        clc                             ; Signal success
@error:
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
        bcs     @error
        jsr     fp0_is_zero             ; Check if zero
        beq     @next_line              ; If zero then don't execute the THEN or any other statements on this line
        jsr     dispatch_statement      ; Otherwise execute the THEN
        clc
@error:
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
        sta     primary_stack+Control::next_line_ptr,x
        lda     next_line_ptr+1
        sta     primary_stack+Control::next_line_ptr+1,x
        lda     next_line_pos
        sta     primary_stack+Control::next_line_pos,x
        txa                             ; Move stack pointer back to A
@done:
        rts
