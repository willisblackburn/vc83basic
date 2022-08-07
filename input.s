.include "macros.inc"
.include "basic.inc"

; INPUT statement:

.assert TOKEN_END_REPEAT = 0, error

exec_input:
        lda     #'?'                    ; Prepare to print '?' prompt
        jsr     putchar
        jsr     readline
        mva     #0, bp                  ; Reset the read position
        jsr     decode_byte             ; Read the variable
        beq     @done                   ; It was TOKEN_END_REPEAT, nothing more to read
@next_var:
        jsr     set_variable_value_ptr  ; Sets variable_value_ptr to the storage for this variable
        jsr     read_number             ; Returns value in AX
        bcs     @error                  ; Failed to read a number
        jsr     set_variable_value      ; Store the value
        jsr     decode_byte             ; Any more?
        beq     @done                   ; No; finish
        tay                             ; Variable is safe in Y
        jsr     parse_argument_separator    ; Number must be followed by ','
        tya                             ; Move variable back to A; doesn't affect carry
        bcs     exec_input              ; If no ',' then prompt again
        bcc     @next_var               ; Unconditional branch to read next var

@done:
        clc
@error:
        rts
