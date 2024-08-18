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
        jmp     assign_variable

@error:
        rts

; Pops a value from the stack and copies it into the variable identified by variable_ptr.
; variable_ptr = pointer to the variable's data in the variable name table

assign_variable:
        mvax    variable_ptr, dst_ptr   ; Copy into variable data
        lda     psp                     ; Get stack pointer
        ldx     #>primary_stack         ; Segment of stack
        ldy     #.sizeof(Float)
        jsr     copy_y_from             ; Copy from stack into variable data
        lda     #.sizeof(Float)         ; Discard from stack
        jsr     stack_free
        clc                             ; Success
        rts
