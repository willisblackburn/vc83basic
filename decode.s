.include "macros.inc"
.include "basic.inc"

.zeropage

; The vector table pointer that was passed into decode_expression
decode_expression_vector_table_ptr: .res 2

.code

; Functions to decode values from the token stream.
; We don't have to worry about errors since we're decoding what we previously encoded.
; For all functions, lp is the read position in line_ptr.

; Decodes the an expression and invokes handlers as it encounters expression elements.
;   1xxx xxxx -> 0 (variable)
;   0000 0000 -> x (will never be dispatched)
;   0000 0001 -> 1 (number)
;   0000 0002 -> 2 (subexpression)
; AX = the table of vectors for dispatching

.assert TOKEN_NO_VALUE = 0, error
.assert TOKEN_PAREN = 1, error
.assert TOKEN_UNARY_OP = $08, error
.assert TOKEN_OP = $10, error
.assert TOKEN_NUM = $20, error
.assert TOKEN_VAR = $80, error

.assert XH_VAR = 0, error
.assert XH_NUM = 1, error
.assert XH_OP = 2, error
.assert XH_UNARY_OP = 3, error
.assert XH_PAREN = 4, error

decode_expression:
        stax    decode_expression_vector_table_ptr  ; Store the value passed in AX as the vector table
        jmp     @start
@loop:
        adc     #(XH_PAREN - TOKEN_PAREN)   ; Generate handler by aligning PAREN handler index with token
        tay                             ; Transfer into Y for dispatch
@dispatch:
        ldax    decode_expression_vector_table_ptr  ; Remember what vector table we're using
        jsr     invoke_indexed_vector   ; Invoke the vector using the existng vector_table_ptr; value is in X
@start:
        ldy     lp                      ; Peek at next byte in token stream
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
        inc     lp                      ; Each handler is unique from this point so advance past the byte
        txa                             ; It's in the range 0-7; see if it's zero (TOKEN_NO_VALUE)
        bne     @loop                   ; If not zero then keep doing stuff; carry is clear here due to shifts
        rts

; Decodes a number and returns it in FPA.
; BC SAFE, DE SAFE

decode_number:
        ldy     lp                      ; Buffer index
        iny                             ; Skip past TOKEN_NUM
        ldx     #0                      ; FPA index
@loop:
        lda     (line_ptr),y
        sta     FPA,x
        inx
        iny
        cpx     #.sizeof(Float)         ; Copied everything?
        bne     @loop
        sty     lp                      ; Store line position
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
        ldy     lp                      ; Read lp into Y and increment
        inc     lp  
        and     (line_ptr),y            ; AND byte with mask and return
        rts
