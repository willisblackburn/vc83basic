.include "macros.inc"
.include "basic.inc"

; LET statement:

exec_let:
        jsr     decode_variable         ; Read the variable
        jsr     set_variable_value_ptr  ; Address of variable data in AX
        jsr     get_argument_value      ; Value is in AX
        jmp     set_variable_value
