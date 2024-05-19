.include "macros.inc"
.include "basic.inc"

; Functions to decode values from the token stream.
; We don't have to worry about errors since we're decoding what we previously encoded.
; For all functions, line_pos is the read position in line_ptr.

; Decodes the an expression and invokes handlers as it encounters expression elements.
;   1xxx xxxx -> 0 (variable)
;   0000 0000 -> x (will never be dispatched)
;   0000 0001 -> 1 (number)
;   0000 0002 -> 2 (subexpression)
; AX = the table of vectors for dispatching

.assert TOKEN_NO_VALUE = 0, error
.assert TOKEN_PAREN = 1, error
.assert TOKEN_STRING = 2, error
.assert TOKEN_UNARY_OP = $08, error
.assert TOKEN_OP = $10, error
.assert TOKEN_NUM = $20, error
.assert TOKEN_VAR = $80, error

.assert XH_VAR = 0, error
.assert XH_NUM = 1, error
.assert XH_OP = 2, error
.assert XH_UNARY_OP = 3, error
.assert XH_PAREN = 4, error
.assert XH_STRING = 5, error

decode_expression:
        stax    decode_expression_vector_table_ptr  ; Store the value passed in AX as the vector table
        jmp     @start
@loop:
        adc     #(XH_PAREN - TOKEN_PAREN)   ; Generate handler by aligning PAREN handler index with token
        tay                             ; Transfer into Y for dispatch
@dispatch:
        ldax    decode_expression_vector_table_ptr  ; Remember what vector table we're using
        jsr     invoke_indexed_vector   ; Invoke the vector for the type of token we found
        bcs     @done                   ; The handler failed
@start:
        ldy     line_pos                ; Peek at next byte in token stream
        lda     (line_ptr),y
        ldy     #XH_VAR                 ; First handler is VAR
        tax                             ; Store it in X for now (sets flags from decoded byte)
        bmi     @dispatch               ; Handle variable           (1xxx xxxx)
        iny                             ; Advance to next handler
        asl     A                       ; Bit 6 into MSB
        asl     A                       ; Bit 5 into MSB
        bmi     @dispatch               ; Handle number             (001x xxxx)
        iny
        asl     A                       ; Bit 4 into MSB
        bmi     @dispatch               ; Handle operator           (0001 xxxx)
        iny
        asl     A                       ; Bit 3 into MSB
        bmi     @dispatch               ; Handle unary operator     (0000 1xxx)
        inc     line_pos                ; Each handler is unique from this point so advance past the byte
        txa                             ; It's in the range 0-7; see if it's zero (TOKEN_NO_VALUE)
        bne     @loop                   ; If not zero then keep doing stuff; carry is clear here due to shifts
@done:
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

; Decodes a string.
; Returns the address of the string in AX.
; Upon entry, line_pos must point to the first byte of the string data, i.e., one byte past TOKEN_STRING.

decode_string:
        lda     line_pos                ; line_pos is now offset of first string bytE
        tax                             ; Copy into X and Y
        tay
        lda     (line_ptr),y            ; Load the length
        sec                             ; Set carry to account for length byte
        adc     line_pos                ; Add in line_pos; this will not overflow so carry will remain clear
        sta     line_pos                ; Update line_pos to point past string
        txa                             ; Get offset back into A
        adc     line_ptr                ; Add line_ptr to get address of string
        ldx     line_ptr+1
        bcc     @no_carry
        inx                             ; Add to low byte set carry so increment high byte
@no_carry:
        rts

decode_variable:
        lda     #$7F
        bne     decode_byte_with_mask   ; Unconditional jump

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
