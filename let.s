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
        lda     variable_type           ; Load the variable type
        tax                             ; While we're here, load the size of the variable type into Y
        ldy     type_size_table,x       ; Replace Y with the size of the type
        jsr     stack_free_value_with_type
        bcs     @error
        txa                             ; Becomes low byte of source address
        ldx     #>stack                 ; Stack page
        jsr     copy_y_from             ; Copy from stack into variable data
        clc                             ; Success
@error:
        rts
