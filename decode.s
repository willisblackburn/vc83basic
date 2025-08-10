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
.assert XH_VAR = 3, error
.assert XH_PAREN = 4, error

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
        cmp     #10
        bcc     @dispatch
        iny                             ; Variable
        sbc     #('A' - '0')
        cmp     #26                     ; Is it one of 26 letters starting with 'A'?
        bcc     @dispatch
        iny                             ; Subexpression start
        cmp     #<('(' - 'A')
        beq     @dispatch
@end:
        clc                             ; None of the above; probably ')' or ',' or ';' so return success
@error:
        rts

; Decodes a number and returns it in AX.
; DE SAFE

decode_number:
        ldax    line_ptr
        ldy     line_pos
        jsr     read_number             ; May fail with carry set
        sty     line_pos                ; Update line_pos
        rts

; Decodes a variable name and set up decode_name_ptr and decode_name_length.

decode_name:
        lda     line_pos                ; Add line_pos to line_ptr to get decode_name_ptr
        clc
        adc     line_ptr
        sta     decode_name_ptr
        lda     line_ptr+1
        adc     #0                      ; Will leave carry clear since decode_name_ptr calculation should not roll over
        sta     decode_name_ptr+1
        ldy     #0                      ; Search for the end of the name starting at position 0
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
        rts

; Decodes a single byte and returns it in A.
; The last instruction loads A, so this function will return with the Z and N flags set accordingly.

decode_byte:
        ldy     line_pos                ; Read line_pos into Y and increment
        inc     line_pos  
        lda     (line_ptr),y            ; Load and return the byte
        rts
