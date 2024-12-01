.include "macros.inc"
.include "basic.inc"

; LET statement:

exec_let:
        jsr     decode_name             ; Sets decode_name_ptr and decode_name_length
        jsr     find_or_add_variable
        bcs     @error

; At this point name_ptr will be pointing to the variable data.
; Store it in variable_ptr because we might need name_ptr when parsing the right hand value.

@found:
        mvax    name_ptr, variable_ptr
        jsr     evaluate_expression     ; Value is in AX
        ldy     #0                      ; Index variable value with Y
        sta     (variable_ptr),y        ; Low byte
        iny
        txa
        sta     (variable_ptr),y        ; High byte
        clc                             ; Success
@error:
        rts
