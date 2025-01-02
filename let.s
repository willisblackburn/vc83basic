.include "macros.inc"
.include "basic.inc"

; LET statement:

exec_let:
        jsr     decode_name             ; Sets decode_name_ptr and decode_name_length
        jsr     find_or_add_variable
        bcs     @error

; At this point name_ptr will be pointing to the variable data.
; Store it in variable_ptr because we might need name_ptr when parsing the right hand value.

        mvax    name_ptr, variable_ptr
        mva     decode_name_type, variable_type
        jsr     evaluate_expression
        jmp     assign_variable

@error:
        rts

; Pops a value from the stack and copies it into the variable identified by variable_ptr.
; variable_ptr = pointer to the variable's data in the variable name table

assign_variable:
        mvax    variable_ptr, dst_ptr   ; Copy into variable data
        ldy     stack_pos               ; Get stack pointer
        ldx     stack+Value::type,y     ; Get the type of the value on the stack
        cpx     variable_type           ; Compare vs. variable type
        bne     @error                  ; Value and variable are different types
        tya                             ; Becomes low byte of source address
        ldy     type_size_table,x       ; Replace Y with the size of the type
        ldx     #>stack                 ; Stack page
        jsr     copy_y_from             ; Copy from stack into variable data
        jsr     stack_free_value
        clc                             ; Success
        rts

@error:
        sec
        rts
