.include "macros.inc"
.include "basic.inc"

; Functions in this module are only used when parsing program lines and are optimzed for space over speed.
; All functions write to the output buffer at index line_pos and update line_pos.
; All functions return carry clear if ok or carry set if out of space.
; All functions clobber X, so save it if you need it.

; Encodes a number.
; AX = the number to encode
; Y SAFE, DE SAFE

encode_number:
        stax    BC
        lda     #TOKEN_NUM
        jsr     encode
        lda     B
        jsr     encode
        lda     C
        jmp     encode_byte

; Encodes a variable by its ID.
; A = the variable ID
; Y SAFE, BC SAFE, DE SAFE

encode_variable:
        ora     #TOKEN_VAR              ; Variables are encoded with the high bit set
        bne     encode_byte

; Encodes an operator.
; A = the operator ID
; Y SAFE, BC SAFE, DE SAFE

encode_operator:
        ora     #TOKEN_OP               ; OR the value with the operator token
        bne     encode_byte

; Encodes a unary operator.
; A = the operator ID
; Y SAFE, BC SAFE, DE SAFE

encode_unary_operator:
        ora     #TOKEN_UNARY_OP         ; OR the value with the unary operator token
        bne     encode_byte

; Encodes the TOKEN_NO_VALUE token

encode_no_value:
        lda     #TOKEN_NO_VALUE

; Fall through

; Encodes a single byte.
; A = the byte to encode
; Y SAFE, BC SAFE, DE SAFE

encode_byte:
        jsr     encode
        rts

; Encodes a single byte and returns to the caller's caller on failure.
; A = the byte to encode
; On error, pops the return address off the stack and then does RTS to the caller's return address. This is so
; the caller doesn't have to check error status after encoding each byte error. Of course this implies the caller
; *can't* handle the error. Also, the caller can't have anything other than its own return address on the stack when
; calling this function.
; Y SAFE, BC SAFE, DE SAFE

encode:
        ldx     line_pos
        cpx     #(254 - Line::data - 1) ; Max length = 255 - 1 (for this byte) - space for END line in immediate mode
        bcs     @error
        sta     line_buffer,x
        inc     line_pos
        rts

@error:
        pla                             ; Discard the return address 
        pla     
        rts                             ; Return to the caller's caller
