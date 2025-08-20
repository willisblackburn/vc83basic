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
        ldax    #buffer                 ; Point to buffer
        ldy     buffer_pos              ; Starting at buffer_pos
        jsr     string_to_fp            ; Parse the number
        bcs     @done                   ; Failed to read a number
        sty     buffer_pos              ; Update buffer_pos
        jsr     push_fp0                ; Push FP0 onto the value stack
        jsr     assign_variable         ; Store the value
        jsr     decode_byte             ; Read the next byte, which is either ',' or 0
        clc                             ; Clear carry in case we're done            
        beq     @done                   ; It was 0, nothing more to read
        ldy     buffer_pos              ; Prepare to skip past the argument separator, if present
        jsr     read_argument_separator ; We read something from this line so need a ',' to continue
        sty     buffer_pos              ; Save back new buffer_pos
        bcc     exec_input              ; Didn't find ',' so issue a new prompt
        bcs     @next_var               ; Otherwise just read the next variable
@done:
        rts
