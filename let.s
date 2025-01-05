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
        jsr     evaluate_expression     ; Value is in AX
        jmp     assign_variable

@error:
        rts

; Assigns the value in AX to the variable identified by name_ptr.
; AX = the variable value
; name_ptr = pointer to the variable's data in the variable name table

assign_variable:
        ldy     #0                      ; Index variable value with Y
        sta     (name_ptr),y            ; Low byte
        iny
        txa
        sta     (name_ptr),y            ; High byte
        clc                             ; Success
        rts
