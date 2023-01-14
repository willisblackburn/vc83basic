.include "macros.inc"
.include "basic.inc"

; PRINT statement:

exec_print:
        jsr     evaluate_expression     ; Leaves value on stack
        jsr     pop_fp0                 ; Get the value
        jsr     print_number            ; Print the number
        jsr     newline
        clc                             ; Print always succeeds
        rts

; Prints the value in FPA to standard output.

print_number:
        mva     #0, bp
        jsr     fp_to_string            ; Format into buffer
        ldax    #buffer
        ldy     bp
        jmp     write
