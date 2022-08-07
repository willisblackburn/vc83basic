.include "macros.inc"
.include "basic.inc"

; PRINT statement:

exec_print:
        jsr     get_argument_value      ; Returns value to print in AX
        jsr     print_number            ; Print the number
        jsr     newline
        rts

; Stop-gap function...

print_number:
        mvy     #0, bp
        jsr     format_number
        ldax    #buffer
        ldy     bp
        jmp     write

