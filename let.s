.include "macros.inc"
.include "basic.inc"

; LET statement:

exec_let:
        jsr     decode_name             ; Sets decode_name_ptr and decode_name_length
        phzp    DECODE_NAME_STATE, DECODE_NAME_STATE_SIZE   ; Remember the decoded name
        jsr     evaluate_expression     ; Value is now on the evaluation stack
        plzp    DECODE_NAME_STATE, DECODE_NAME_STATE_SIZE   ; Recover the decoded name
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
        lda     #TYPE_NUMBER            ; Make sure it's a number
        jsr     stack_free_value_with_type
        bcs     @error
        txa                             ; Becomes low byte of source address
        ldx     #>stack                 ; Stack page
        ldy     #.sizeof(Float)
        jsr     copy_y_from             ; Copy from stack into variable data
        clc                             ; Success
@error:
        rts
