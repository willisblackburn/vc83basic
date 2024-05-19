.include "macros.inc"
.include "basic.inc"

; PRINT statement:

exec_print:
        jsr     evaluate_expression     ; Leaves value on stack
        jsr     pop_value               ; Get the value
        jsr     print_number            ; Print the number
        jsr     newline
        clc                             ; Print always succeeds
        rts

; Stop-gap function...

print_number:
        mvy     #0, buffer_pos
        jsr     format_number
        ldax    #buffer
        ldy     buffer_pos
        jmp     write
