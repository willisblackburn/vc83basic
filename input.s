
; INPUT statement:

.assert TYPE_NUMBER = $00, error

exec_input:
        lda     #'?'                    ; Prepare to print '?' prompt
        jsr     putch
        jsr     readline
        mva     #0, buffer_pos          ; Reset the read position
@next_var:
        jsr     decode_name             ; Read the variable name
        jsr     find_or_add_variable
        bcs     @done
        lda     decode_name_type        ; Is it a number or a string?
        bne     @string                 ; It's a string
        ldax    #buffer                 ; Point to buffer
        ldy     buffer_pos              ; Starting at buffer_pos
        jsr     string_to_fp            ; Parse the number
        bcs     @format_error           ; Failed to read a number
        sty     buffer_pos              ; Update buffer_pos
        jsr     push_fp0                ; Push FP0 onto the value stack

@assign:
        jsr     assign_variable         ; Store the value
        jsr     decode_byte             ; Read the next byte, which is either ',' or 0
        clc                             ; Clear carry in case we're done            
        beq     @done                   ; It was 0, nothing more to read
        ldy     buffer_pos              ; Prepare to skip past the argument separator, if present
        jsr     find_printable_character    ; We read something from this line so need a ',' to continue
        cmp     #','                    ; Was it the separator?
        bne     exec_input              ; Nope, just issue a new prompt
        iny                             ; Skip separator        
        sty     buffer_pos              ; Save back new buffer_pos
        bne     @next_var               ; Read the next variable
@done:
        rts

@string:
        ldax    #buffer
        ldy     buffer_pos
        jsr     read_string
        bcs     @format_error
        sty     buffer_pos              ; Update buffer_pos to next read position
        jsr     push_string             ; Push result string onto the stack
        jmp     @assign

@format_error:
        raise   ERR_FORMAT_ERROR
