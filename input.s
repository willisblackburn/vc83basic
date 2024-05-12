.include "macros.inc"
.include "basic.inc"

; INPUT statement:

.assert TOKEN_NO_VALUE = 0, error

exec_input:
        lda     #'?'                    ; Prepare to print '?' prompt
        jsr     putch
        jsr     readline
        mva     #0, buffer_pos          ; Reset the read position
@next_var:
        jsr     decode_variable         ; Read the variable
        jsr     set_variable_value_ptr  ; Sets variable_value_ptr to the storage for this variable
        jsr     read_number             ; Returns value in AX
        bcs     @error                  ; Failed to read a number
        jsr     set_variable_value      ; Store the value
        ldy     line_pos                ; Peek at the next byte
        lda     (line_ptr),y            
        beq     @done                   ; It was TOKEN_NO_VALUE, nothing more to read
        jsr     parse_argument_separator    ; We read something from ths line so need a ',' to continue
        bcc     exec_input              ; Didn't find ',' so issue a new prompt
        bcs     @next_var               ; Otherwise just read the next variable

@done:
        clc
@error:
        rts
