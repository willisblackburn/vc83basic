.include "macros.inc"
.include "basic.inc"

; INPUT statement:

exec_input:
        jsr     decode_byte             ; Read the variable
        jsr     set_variable_value_ptr  ; Address of variable data in AX
        lda     #'?'                    ; Prepare to print '?' prompt
        jsr     putchar
        jsr     readline
        mva     #0, r                   ; Start parsing at position 0
        jsr     read_number
        jmp     set_variable_value
