.include "macros.inc"
.include "basic.inc"

; LET statement:

exec_let:
        jsr     decode_variable         ; Read the variable
        pha                             ; Remember it while we figure out the value to assign to it
        jsr     evaluate_expression     ; Leaves the result on the stack
        pla                             ; Get the variable back
        jsr     set_variable_value_ptr  ; Calculate address of variable
        jsr     pop_value               ; Get the evaluated value
        jsr     set_variable_value      ; And save it
        clc                             ; Signal success
        rts
