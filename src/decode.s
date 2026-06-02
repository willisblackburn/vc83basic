; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

; Functions to decode values from the token stream.
; For all functions, line_pos is the read position in line_ptr.

; Decodes a number and returns it in FP0.
; BC SAFE, DE SAFE

decode_number:
        ldax    line_ptr
        ldy     line_pos
        jsr     string_to_fp            ; May fail with carry set
        bcs     raise_format_error
        sty     line_pos                ; Update line_pos
        rts

; Decodes a string.
; On return, string_ptr will point to the decoded string.

decode_string:
        ldax    line_ptr                ; Prepare for read_string
        ldy     line_pos
        jsr     read_string
        bcs     raise_format_error
        sty     line_pos
        rts

raise_format_error:
        raise   ERR_FORMAT_ERROR

; Decodes a variable name and set up decode_name_ptr, decode_name_length, and decode_name_type.
; BC SAFE, DE SAFE

.assert TYPE_NUMBER = $00, error
.assert TYPE_STRING = $01, error

decode_name:
        lda     line_pos                ; Add line_pos to line_ptr to get decode_name_ptr
        clc
        adc     line_ptr
        sta     decode_name_ptr
        lda     line_ptr+1
        adc     #0                      ; Will leave carry clear since decode_name_ptr calculation should not roll over
        sta     decode_name_ptr+1
        ldy     #0                      ; Search for the end of the name starting at position 0
        sty     decode_name_type        ; Variable is TYPE_NUMBER (0) unless we learn otherwise
        sty     decode_name_arity       ; Default to arity 0 meaning not an array
@next:
        lda     (decode_name_ptr),y
        bmi     @last
        iny
        bne     @next

@last:
        iny                             ; Account for last character
        sty     decode_name_length
        tya                             ; Add to line_pos; carry should be clear
        adc     line_pos
        sta     line_pos                ; Update line_pos
        dey                             ; Back up one so we can check if the last character is '$'
        lda     (decode_name_ptr),y
        cmp     #'$' | EOT              ; If it's there, it will have the high bit set
        bne     @not_string
        inc     decode_name_type        ; Make it TYPE_STRING (1)
@not_string:
        iny                             ; Restore Y to where it previously was, past the end of the name
        lda     (decode_name_ptr),y     ; See if the next character is '('
        cmp     #'('
        bne     @not_array
        dec     decode_name_arity       ; Remember it was an array (will figure out real arity later)
        inc     line_pos                ; Skip past the '('
@not_array:
        rts

; Decodes a single byte and returns it in A.
; The last instruction loads A, so this function will return with the Z and N flags set accordingly.

decode_byte:
        ldy     line_pos                ; Read line_pos into Y and increment
        inc     line_pos  
        lda     (line_ptr),y            ; Load and return the byte
        rts

; EORs the next byte from the stream with a value in A, which sets the Z flag if the values were the same.

peek_byte:
        ldy     line_pos                ; Read line_pos into Y and increment
        lda     (line_ptr),y            ; Load and return the byte
        rts
