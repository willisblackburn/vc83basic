.include "macros.inc"
.include "basic.inc"

; INPUT statement:

.assert TOKEN_END_REPEAT = 0, error

exec_input:
        lda     #'?'                    ; Prepare to print '?' prompt
        jsr     putchar
        jsr     readline
        mva     #0, bp                  ; Reset the read position
@next_var:
        jsr     decode_byte             ; Read the variable
        beq     @done                   ; It was TOKEN_END_REPEAT, nothing more to read
        jsr     set_variable_value_ptr  ; Sets variable_value_ptr to the storage for this variable
        jsr     read_number             ; Returns value in AX
        bcs     @error                  ; Failed to read a number
        jsr     set_variable_value      ; Store the value
        jsr     decode_byte             ; Read the variable
        beq     @done                   ; It was TOKEN_END_REPEAT, nothing more to read
        dec     lp                      ; Otherwise back up
        jsr     parse_argument_separator    ; We read something from ths line so need a ',' to continue
        bcs     exec_input              ; Didn't find ',' so issue a new prompt
        jmp     @next_var               ; Otherwise just read the next variable

@done:
        clc
@error:
        rts
