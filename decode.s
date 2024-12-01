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
.assert XH_PAREN = 5, error

decode_expression:
        stax    decode_expression_vector_table_ptr  ; Store the value passed in AX as the vector table
        jmp     @start

@dispatch:
        ldax    decode_expression_vector_table_ptr  ; Remember what vector table we're using
        jsr     invoke_indexed_vector   ; Invoke the vector for the type of token we found
        bcs     @error                  ; The handler failed
@start:
        ldy     line_pos                ; Peek at next byte in token stream
        lda     (line_ptr),y
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
        bcc     @dispatch
        iny                             ; Subexpression start
        cmp     #<('(' - 'A')
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
        iny                             ; Skip over the 0 that terminated the number
        sty     line_pos                ; Update line_pos
        rts

decode_int:
        jsr     decode_number
        jmp     truncate_fp_to_int

; Decodes a string.
; Returns the address of the string in AX.

decode_string:
        ldax    line_ptr                ; Prepare for read_string
        ldy     line_pos
        jsr     read_string
        sty     line_pos
        rts

; Decodes a variable name and set up match_ptr and match_length.
; X SAFE, BC SAFE, DE SAFE

decode_name:
        lda     line_pos                ; Add line_pos to line_ptr to get match_ptr
        clc
        adc     line_ptr
        sta     match_ptr
        lda     line_ptr+1
        adc     #0                      ; Will leave carry clear since match_ptr calculation should not roll over
        sta     match_ptr+1
        ldy     #0                      ; Search for the end of the name starting at position 0
@next:
        lda     (match_ptr),y
        bmi     @last
        iny
        bne     @next

@last:
        iny                             ; Account for last character
        sty     match_length
        tya                             ; Add to line_pos; carry should be clear
        adc     line_pos
        sta     line_pos                ; Update line_pos
        rts

decode_operator:
        lda     #$0F
        bne     decode_byte_with_mask   ; Unconditional jump

decode_unary_operator:
        lda     #$07
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
