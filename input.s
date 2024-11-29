.include "macros.inc"
.include "basic.inc"

; INPUT statement:

exec_input:
        lda     #'?'                    ; Prepare to print '?' prompt
        jsr     putch
        jsr     readline
        mva     #0, buffer_pos          ; Reset the read position
@next_var:
        jsr     decode_name             ; Read the variable name
        jsr     find_or_add_variable
        bcs     @done
        mvax    name_ptr, variable_ptr
        ldax    #buffer
        ldy     buffer_pos
        jsr     read_number
        bcs     @done
        sty     buffer_pos              ; Update buffer_pos
        jsr     assign_variable
        ldy     line_pos                ; Peek at the next byte
        lda     (line_ptr),y
        clc                             ; Clear carry in case we're done            
        beq     @done                   ; It was 0, nothing more to read
        jsr     parse_argument_separator    ; We read something from ths line so need a ',' to continue
        bcc     exec_input              ; Didn't find ',' so issue a new prompt
        bcs     @next_var               ; Otherwise just read the next variable
@done:
        rts
