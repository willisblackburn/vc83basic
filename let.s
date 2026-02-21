
; LET statement:

exec_let:
        jsr     decode_name             ; Sets decode_name_ptr and decode_name_length
        inc     line_pos                ; Skip terminator
        jsr     evaluate_expression     ; Value is now on the evaluation stack
        bcs     @error
        jsr     find_or_add_variable
        bcs     @error
        jmp     assign_variable

@error:
        rts

; Pops a value from the stack and copies it into the variable identified by name_ptr.
; name_ptr = pointer to the variable's data in the variable name table

assign_variable:
        mvax    name_ptr, dst_ptr       ; Copy into variable data
        lda     decode_name_type        ; Load the variable type
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
