.include "macros.inc"
.include "basic.inc"

; Functions to decode values from the token stream.
; For all functions, line_pos is the read position in line_ptr.

; Decodes the an expression and invokes handlers as it encounters expression elements.
; AX = the table of vectors for dispatching
; Returns carry clear on success, or carry set if either one of the handlers failed (returned carry set) or the
; function encountered an invalid expression token (which should not happen).

.assert TOKEN_NO_VALUE = 0, error

.assert XH_VAR = 0, error
.assert XH_OP = 1, error
.assert XH_UNARY_OP = 2, error
.assert XH_NUM = 3, error
.assert XH_PAREN = 4, error

decode_expression:
        stax    decode_expression_vector_table_ptr  ; Store the value passed in AX as the vector table
        jmp     @start

@inc_dispatch:
        inc     line_pos
@dispatch:
        ldax    decode_expression_vector_table_ptr  ; Remember what vector table we're using
        jsr     invoke_indexed_vector   ; Invoke the vector for the type of token we found
        bcs     @error                  ; The handler failed
@start:
        ldy     line_pos                ; Peek at next byte in token stream
        lda     (line_ptr),y
        beq     @end                    ; If we're at the end of the expression then stop
        ldy     #XH_VAR                 ; First handler is VAR
        tax                             ; Store token in X for now
        and     #$60                    ; Start of variable name
        bne     @dispatch
        iny
        txa
        and     #TOKEN_OP               ; Binary operator
        bne     @dispatch
        iny
        txa
        and     #TOKEN_UNARY_OP         ; Unary operator
        bne     @dispatch
        iny
        cpx     #TOKEN_NUM              ; Number
        beq     @dispatch
        iny
        cpx     #TOKEN_PAREN            ; Subexpression start
        beq     @inc_dispatch
        sec                             ; None of the above; set carry to indicate failure
@error:
        rts

@end:
        inc     line_pos                ; Consume final TOKEN_NO_VALUE
        clc                             ; Success
        rts

; Decodes a number and returns it in FP0.
; BC SAFE, DE SAFE

decode_number:
        inc     line_pos                ; Skip past token
        ldy     line_ptr+1              ; High byte of line_ptr
        lda     line_ptr                ; Low byte
        clc
        adc     line_pos                ; Add line_pos
        bcc     @no_carry
        iny                             ; Low byte addition overflowed so increment high byte
@no_carry:
        jsr     load_fp0
        jmp     advance_lp_sizeof_float

decode_int:
        jsr     decode_number
        jmp     truncate_fp_to_int

; Decodes a variable name and set up name_ptr and name_length.
; X SAFE, BC SAFE, DE SAFE

decode_name:
        lda     line_pos                ; Add line_pos to line_ptr to get name_ptr
        clc
        adc     line_ptr
        sta     name_ptr
        lda     line_ptr+1
        adc     #0                      ; Will leave carry clear since name_ptr calculation should not roll over
        sta     name_ptr+1
        ldy     #0                      ; Search for the end of the name starting at position 0
@next:
        lda     (name_ptr),y
        bmi     @last
        iny
        bne     @next

@last:
        iny                             ; Account for last character
        sty     name_length
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
