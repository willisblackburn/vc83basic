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
        jsr     decode_name             ; Read the variable name
        jsr     find_or_add_variable
        bcs     @done
        mvax    record_ptr, variable_ptr    ; Set up target for assign_variable
        jsr     string_to_fp            ; Parse the number
        bcs     @done                   ; Failed to read a number
        jsr     push_fp0                ; Push FP0 onto the value stack
        jsr     assign_variable         ; Store the value
        ldy     line_pos                ; Peek at the next byte
        lda     (line_ptr),y
        clc                             ; Clear carry in case we're done            
        beq     @done                   ; It was TOKEN_NO_VALUE, nothing more to read
        jsr     parse_argument_separator    ; We read something from ths line so need a ',' to continue
        bcc     exec_input              ; Didn't find ',' so issue a new prompt
        bcs     @next_var               ; Otherwise just read the next variable
@done:
        rts
