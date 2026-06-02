; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

; stack must be page-aligned
.assert <stack = 0, error

; We use type to distinguish between Value and Control on the stack, so make sure they're at the same offset.
.assert Control::type = Value::type, error

; GOSUB statement:

exec_gosub:
        jsr     push_next_line_ptr      ; Save return address
        lda     #0                      ; Set variable field to an invalid pointer
        sta     stack+Control::variable_name_ptr+1,x

; Fall through

; GOTO statement:
; Also used by exec_gosub and exec_restore as a general function for reading a line number and finding that line.

exec_goto:
        jsr     get_line_number         ; Go get the line number
        jsr     find_line
        raics   ERR_LINE_NOT_FOUND
        rts

; ON...GOTO/GOSUB statement:

exec_on_goto_gosub:
        jsr     evaluate_expression     ; Evaluate the "ON" expression
        jsr     decode_byte             ; Next byte tells us if it's GOTO or GOSUB
        cmp     #TOKEN_CLAUSE | CLAUSE_GOTO     ; If Z flag then we're GOTO, else GOSUB
        php                             ; Remember what we learned
        jsr     pop_int_fp0             ; FP0 -> integer in AX
        sta     B
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
        plp                             ; Recover the flags from the GOSUB check
        beq     exec_goto
        bne     exec_gosub              ; Unconditional    

@zero:
        plp                             ; Discard the flags we didn't use
        rts

@out_of_range:
        jmp     raise_out_of_range

; RETURN statement:

exec_return:
        ldx     stack_pos               ; Check stack pointer
        cpx     #PRIMARY_STACK_SIZE     ; Stack empty?
        beq     @return_without_gosub
        lda     stack+Control::variable_name_ptr+1,x    ; Check if high byte of variable name pointer is 0
        bne     @return_without_gosub   ; Variable was not GOSUB signal
        jsr     restore_next_line_ptr
        jmp     exec_pop_2

@return_without_gosub:
        raise   ERR_RETURN_WITHOUT_GOSUB

; FOR statement:

.assert TYPE_NUMBER = $00, error

exec_for:
        jsr     push_next_line_ptr      ; Save return address
        jsr     decode_name             ; Get the name (now in decode_name_ptr)
        lda     decode_name_type        ; No string variables please
        bne     raise_invalid_variable
        lda     decode_name_arity       ; Or arrays
        bmi     raise_invalid_variable
        inc     line_pos                ; Skip terminator following name
        jsr     evaluate_expression     ; Start value
        inc     line_pos                ; Skip terminator
        jsr     find_or_add_variable    ; name_ptr now points to variable data
        jsr     assign_variable         ; Assign start value to variable
        ldx     stack_pos               ; Store pointer to name in variable name table
        lda     name_ptr                ; Calculate start of name: name_ptr - decode_name_length
        sec
        sbc     decode_name_length
        sta     stack+Control::variable_name_ptr,x
        lda     name_ptr+1
        sbc     #0
        sta     stack+Control::variable_name_ptr+1,x
        jsr     evaluate_expression     ; End value
        jsr     pop_fp0                 ; Get the evaluated value
        lda     stack_pos               ; Stack pointer
        adc     #Control::end_value     ; Add the offset of the end value; carry is clear
        ldy     #>stack                 ; Stack page
        jsr     store_fp0               ; Store FP0 there
        jsr     peek_byte               ; Check for STEP
        cmp     #TOKEN_CLAUSE | CLAUSE_STEP
        bne     @no_step
        inc     line_pos
        jsr     evaluate_expression
        jsr     pop_fp0
        jmp     @store_step
@no_step:
        jsr     load_one_fp0
@store_step:
        lda     stack_pos               ; Stack pointer again
        clc
        adc     #Control::step_value    ; Add the offset of the step value
        ldy     #>stack
        jmp     store_fp0               ; Store the step value
        
raise_invalid_variable:
        raise   ERR_INVALID_VARIABLE

; NEXT statement:

exec_next:

; Decode the variable name and see if it matches the one at the top of the stack.

        jsr     decode_name             ; Sets decode_name_ptr
        ldx     stack_pos               ; Load stack position
        cpx     #PRIMARY_STACK_SIZE     ; Check if stack empty
        beq     raise_next_without_for  ; If so then fail
        lda     stack+Control::variable_name_ptr,x  ; Point name_ptr to name in variable name table
        sta     name_ptr
        lda     stack+Control::variable_name_ptr+1,x
        beq     raise_next_without_for  ; If it was zero then top of stack is GOSUB not FOR
        sta     name_ptr+1
        jsr     match_name              ; Make sure it's the right name; Y = name length on success
        bcs     raise_invalid_variable
        jsr     rebase_name_ptr         ; Advance name_ptr past name to variable data
        lday    name_ptr                ; Load variable value directly into FP0
        jsr     load_fp0
        lda     stack_pos               ; Get stack position
        clc
        adc     #Control::step_value    ; Add offset of step value
        ldy     #>stack                 ; Stack page
        jsr     fadd                    ; FP0 = variable value + step
        lday    name_ptr                ; Store updated value back to variable
        jsr     store_fp0
        lda     stack_pos               ; Get stack position again
        clc
        adc     #Control::end_value     ; Calculate address of end value (carry will be clear)
        ldy     #>stack
        jsr     fcmp                    ; Compare current with end value
        beq     restore_next_line_ptr   ; Equal: continue
        ldx     stack_pos               ; Reload stack position (clobbered by fcmp)
        lda     stack+Control::step_value+3,x  ; Check sign of step
        bpl     @positive_step
        bcc     exec_pop_2              ; Negative step: current < end so stop
        bcs     restore_next_line_ptr   ; Negative step: current >= end so continue
@positive_step:
        bcs     exec_pop_2              ; Positive step: current > end so stop

; Fall through

restore_next_line_ptr:
        ldx     stack_pos
        lda     stack+Control::next_line_ptr,x
        sta     next_line_ptr           ; Restore next_line_ptr value
        lda     stack+Control::next_line_ptr+1,x
        sta     next_line_ptr+1
        lda     stack+Control::next_line_pos,x
        sta     next_line_pos           ; Restore next_line_pos value
        rts

raise_next_without_for:
        raise   ERR_NEXT_WITHOUT_FOR                            

; POP statement:
; Returns with the popped stack pointer still in X so caller can use.

exec_pop:
        ldx     stack_pos               ; Check stack pointer
        cpx     #PRIMARY_STACK_SIZE     ; Stack empty?
        bne     exec_pop_2
        jmp     raise_err_stack
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
