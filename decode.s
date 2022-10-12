.include "macros.inc"
.include "basic.inc"

; Functions to decode values from the token stream.
; We don't have to worry about errors since we're decoding what we previously encoded.
; For all functions, lp is the read position in line_ptr.

; Decodes the an expression and invokes handlers as it encounters expression elements.
;   1xxx xxxx -> 0 (variable)
;   0000 0000 -> x (will never be dispatched)
;   0000 0001 -> 1 (number)
;   0000 0002 -> 2 (subexpression)
; vector_table_ptr = the table of vectors for dispatching; must be set up in advance!

.assert TOKEN_NO_VALUE = 0, error
.assert TOKEN_LPAREN = 1, error
.assert TOKEN_RPAREN = 2, error
.assert TOKEN_MINUS = 3, error
.assert TOKEN_NOT = 4, error
.assert TOKEN_OP = $10, error
.assert TOKEN_NUM = $20, error
.assert TOKEN_VAR = $80, error

.assert XH_VAR = 0, error
.assert XH_NUM = 1, error
.assert XH_OP = 2, error
.assert XH_LPAREN = 3, error
 
decode_expression:
        ldy     lp                      ; Peek at next byte in token stream
        lda     (line_ptr),y
        ldy     #XH_VAR                 ; First handler is VAR
        tax                             ; Store it in X for now (sets flags from decoded byte)
        bmi     @dispatch               ; Handle variable (1xxx xxxx)
        iny                             ; Advance to next handler
        asl     A                       ; Bit 6 into MSB
        asl     A                       ; Bit 5 into MSB
        bmi     @dispatch               ; Handle number (001x xxxx)
        iny
        asl     A                       ; Bit 4 into MSB
        bmi     @dispatch               ; Handle operator (0001 xxxx)
        inc     lp                      ; Each handler is unique from this point so advance past the byte
        txa                             ; It's in the range 0-15; see if it's zero (TOKEN_NO_VALUE)
        beq     @done                   ; If zero then done; carry is clear here because we've shifted 0s into it        
        adc     #(XH_LPAREN - TOKEN_LPAREN) ; Generate handler by aligning LPAREN handler index with token
        tay                             ; Transfer into Y for dispatch
@dispatch:
        jsr     invoke_indexed_vector_vt    ; Invoke the vector using the existng vector_table_ptr; value is in X
        jmp     decode_expression

@done:
        rts

; Decodes a number and returns it in AX.

decode_number:
        inc     lp                      ; Advance past number marker token
        inc     lp                      ; Increment read position to high byte 
        ldy     lp                      ; Load position of high byte into Y
        inc     lp                      ; Increment read one position again
        lda     (line_ptr),y            ; Load the high byte of the number
        tax                             ; Move into X
        dey                             ; Decrement Y
        lda     (line_ptr),y            ; Get the low byte of the number into A
        rts     

decode_variable:
        lda     #$7F
        bne     decode_byte_with_mask   ; Unconditional jump

decode_operator:
        lda     #$0F
        bne     decode_byte_with_mask   ; Unconditional jump

; Decodes a single byte and returns it in A.
; The last instruction loads A, so this function will return with the Z and N flags set accordingly.
; The decode_byte_with_mask entry point accepts a mask byte in A and ANDs it with the byte from the token stream.

decode_byte:
        lda     #$FF
decode_byte_with_mask:
        ldy     lp                      ; Read lp into Y and increment
        inc     lp  
        and     (line_ptr),y            ; AND byte with mask and return
        rts
