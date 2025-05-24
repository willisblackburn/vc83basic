.include "macros.inc"
.include "basic.inc"

; Functions to decode values from the token stream.
; For all functions, line_pos is the read position in line_ptr.

; Decodes the an expression and invokes handlers as it encounters expression elements.
; AX = the table of vectors for dispatching
; Returns carry clear on success, or carry set if either one of the handlers failed (returned carry set) or the
; function encountered an invalid expression token (which should not happen).

.assert XH_UNARY_OP = 0, error
.assert XH_OP = 1, error
.assert XH_NUMBER = 2, error
.assert XH_STRING = 3, error
.assert XH_VAR = 4, error
.assert XH_FUNCTION = 5, error
.assert XH_PAREN = 6, error

decode_expression:
        stax    decode_expression_vector_table_ptr  ; Store the value passed in AX as the vector table
        jmp     @start

@dispatch:
        ldax    decode_expression_vector_table_ptr  ; Remember what vector table we're using
        jsr     invoke_indexed_vector   ; Invoke the vector for the type of token we found
        bcs     @error                  ; The handler failed
@start:
        jsr     peek_decode_byte
        beq     @end                    ; If we're at the end of the expression then stop
        and     #$7F                    ; Clear high bit if set
        sec                             ; Set carry for subtracts to follow
        ldy     #XH_UNARY_OP            ; Unary operator
        sbc     #TOKEN_UNARY_OP
        cmp     #8
        bcc     @dispatch
        iny                             ; Binary operator
        sbc     #(TOKEN_OP - TOKEN_UNARY_OP)
        cmp     #16
        bcc     @dispatch
        iny                             ; Number
        sbc     #('0' - TOKEN_OP)
        cmp     #<('.' - '0')
        beq     @dispatch
        cmp     #<('-' - '0')
        beq     @dispatch
        cmp     #10
        bcc     @dispatch
        iny                             ; String
        sbc     #('A' - '0')
        cmp     #<('"'- 'A')
        beq     @dispatch
        iny                             ; Variable
        cmp     #26                     ; Is it one of 26 letters starting with 'A'?
        bcc     @dispatch
        iny                             ; Function
        sbc     #<('`' - 'A')
        cmp     #32
        bcc     @dispatch
        iny                             ; Subexpression start
        cmp     #<('(' - '`')
        beq     @dispatch

        sec                             ; None of the above; set carry to indicate failure (shouldn't happen...)
@error:
        rts

@end:
        inc     line_pos                ; Consume terminating 0
        clc                             ; Success
        rts

; Decodes a number and returns it in FP0.
; BC SAFE, DE SAFE

decode_number:
        ldax    line_ptr
        ldy     line_pos
        jsr     string_to_fp            ; May fail with carry set
        sty     line_pos                ; Update line_pos
        rts

; Decodes a string.
; Returns the address of the string in AX.

decode_string:
        ldax    line_ptr                ; Prepare for read_string
        ldy     line_pos
        jsr     read_string
        sty     line_pos
        rts

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
        sty     decode_name_arity       ; While we have a zero, initialize decode_name_arity
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
        ldx     #TYPE_NUMBER            ; Variable is a number unless we learn otherwise
        dey                             ; Back up one so we can check if the last character is '$'
        lda     (decode_name_ptr),y
        cmp     #'$' | EOT              ; If it's there, it will have the high bit set
        bne     @not_string
        inx                             ; It was a string; change the type
@not_string:
        iny                             ; Restore Y to where it previously was, past the end of the name
        lda     (decode_name_ptr),y     ; See if the next character is '('
        cmp     #'('
        bne     @not_array
        iny                             ; Array arity will be the byte following the end of the name
        lda     (decode_name_ptr),y     ; Copy arity
        sta     decode_name_arity
        inc     line_pos                ; Move line_pos past '(' and arity
        inc     line_pos
@not_array:
        stx     decode_name_type        ; Remember the type
        rts

decode_operator:
        lda     #$0F
        bne     decode_byte_with_mask   ; Unconditional jump

decode_unary_operator:
        lda     #$07
        bne     decode_byte_with_mask   ; Unconditional jump

decode_function:
        lda     #$1F
        bne     decode_byte_with_mask   ; Unconditional jump

; Decodes a single byte and returns it in A.
; The last instruction loads A, so this function will return with the Z and N flags set accordingly.
; The decode_byte_with_mask entry point accepts a mask byte in A and ANDs it with the byte from the token stream.
; X SAFE, BC SAFE, DE SAFE

decode_byte:
        lda     #$FF
decode_byte_with_mask:
        ldy     line_pos                ; Read line_pos into Y and increment
        inc     line_pos  
        and     (line_ptr),y            ; AND byte with mask and return
        rts

; Checks the next byte. JSR to here saves 1 byte for each use.
; Returns the byte in A and the flags set from reading that byte. Leaves Y set to the value in line_pos.
; The caller should increment line_pos if it decided to use the returned value.
; X SAFE, BC SAFE, DE SAFE

peek_decode_byte:
        ldy     line_pos                ; Read line_pos into Y
        lda     (line_ptr),y            ; Peek at next character
        rts