.include "macros.inc"
.include "basic.inc"

; LET statement:

exec_let:
        jsr     decode_name             ; Sets name_ptr and name_length
        jsr     find_or_add_variable
        bcs     @error

; At this point record_ptr will be pointing to the variable data.
; Store it in variable_ptr because we might need record_ptr when parsing the right hand value.

        mvax    record_ptr, variable_ptr
        jsr     evaluate_expression
        jsr     pop_value               ; Get result of expression
        jmp     assign_variable

@error:
        rts

; Assigns the value in AX to the variable identified by variable_ptr.
; AX = the variable value
; variable_ptr = pointer to the variable's data in the variable name table

assign_variable:
        ldy     #0                      ; Index variable value with Y
        sta     (variable_ptr),y        ; Low byte
        iny
        txa
        sta     (variable_ptr),y        ; High byte
        clc                             ; Success
        rts
