; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

; INPUT statement:

.assert TYPE_NUMBER = $00, error

exec_input:
.ifdef enable_io_channels
        bit     channel                 ; Bit 7 is set if explicit channel was given
        bmi     @get_input              ; Skip prompt if explicit channel
.endif
        jsr     peek_byte
        cmp     #TOK_STRING
        bne     @default_prompt
        inc     line_pos                ; Skip TOK_STRING
        jsr     evaluate_string
        lday    string_ptr
        jsr     print_string
        inc     line_pos                ; Skip the ';'
        bne     @get_input

@default_prompt:
        lda     #'?'                    ; Prepare to print '?' prompt
        jsr     putch
@get_input:
        jsr     readline
        bcs     @eof_error              ; If readline returns carry set -> EOF
        tay
        lda     #0
        sta     buffer,y                ; NUL-terminate based on length in A
        mva     #0, buffer_pos          ; Reset the read position
@next_var:
        jsr     get_variable
        bcs     @done
        lda     var_name_type           ; Is it a number or a string?
        bne     @string                 ; It's a string
        ldax    #buffer                 ; Point to buffer
        ldy     buffer_pos              ; Starting at buffer_pos
        jsr     string_to_fp            ; Parse the number
        bcs     @format_error           ; Failed to read a number
        sty     buffer_pos              ; Update buffer_pos

@assign:
        jsr     assign_variable         ; Store the value
        jsr     get_byte                ; Read the next byte, which is either ',' or 0
        beq     @done                   ; It was 0, nothing more to read
        ldy     buffer_pos              ; Prepare to skip past the argument separator, if present
        jsr     skip_whitespace         ; We read something from this line so need a ',' to continue
        cmp     #','                    ; Was it the separator?
        bne     @more_input             ; Nope, just get more input
        iny                             ; Skip separator        
        sty     buffer_pos              ; Save back new buffer_pos
        bne     @next_var               ; Read the next variable
@done:
        rts

@more_input:
.ifdef enable_io_channels
        bit     channel
        bmi     @get_input              ; Explicit channel: skip prompt
.endif
        jmp     @default_prompt

@eof_error:
        jmp     raise_io_error

@string:
        ldax    #buffer
        ldy     buffer_pos
        jsr     read_string
        bcs     @format_error
        sty     buffer_pos              ; Update buffer_pos to next read position
        mvax    string_ptr, S0          ; S0 = string header pointer
        jmp     @assign

@format_error:
        jmp     raise_format_error
