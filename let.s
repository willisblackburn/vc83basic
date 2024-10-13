.include "macros.inc"
.include "basic.inc"

; LET statement:

exec_let:
        jsr     decode_name             ; Sets match_ptr and match_length
        jsr     find_or_add_variable
        bcs     @error

; At this point name_ptr will be pointing to the variable data.
; Store it in variable_ptr because we might need name_ptr when parsing the right hand value.

        mvax    name_ptr, variable_ptr
        jsr     evaluate_expression
        jmp     assign_variable

@error:
        rts

; Pops a value from the stack and copies it into the variable identified by variable_ptr.
; variable_ptr = pointer to the variable's data in the variable name table

assign_variable:
        mvax    variable_ptr, dst_ptr   ; Copy into variable data
        ldx     psp                     ; Get stack pointer
        inx                             ; Skip past the type
        txa                             ; Becomes low byte of source address
        ldx     #>primary_stack         ; Segment of stack
        ldy     #.sizeof(Float)
        jsr     copy_y_from             ; Copy from stack into variable data
        lda     #.sizeof(Value)         ; Discard from stack
        jsr     stack_free
        clc                             ; Success
        rts
