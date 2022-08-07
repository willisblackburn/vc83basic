.include "macros.inc"
.include "basic.inc"

; INPUT statement:

.assert TOKEN_END_REPEAT = 0, error

retry_with_prompt:
        dec     lp                      ; After failing to read separator, back up to retry after new prompt
exec_input:
        lda     #'?'                    ; Prepare to print '?' prompt
        jsr     putchar
        jsr     readline
        mva     #0, bp                  ; Reset the read position
@next_var:
        jsr     decode_byte             ; Read the variable
        beq     @done                   ; It was TOKEN_END_REPEAT, nothing more to read
        tay                             ; Variable is safe in Y
        lda     bp                      ; Check the read position
        beq     @skip_separator         ; If read position is 0 then no separator needed
        jsr     parse_argument_separator    ; We read something from ths line so need a ',' to continue
        bcs     retry_with_prompt       ; Didn't find ',' so issue a new prompt
@skip_separator:
        tya                             ; Variable value back into A
        jsr     set_variable_value_ptr  ; Sets variable_value_ptr to the storage for this variable
        jsr     read_number             ; Returns value in AX
        bcs     @error                  ; Failed to read a number
        jsr     set_variable_value      ; Store the value
        jmp     @next_var

@done:
        clc
@error:
        rts
