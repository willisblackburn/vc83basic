.include "macros.inc"
.include "basic.inc"

; Functions in this module are only used when parsing program lines and are optimzed for space over speed.
; All functions write to the output buffer at index lp and update lp.
; All functions return carry clear if ok or carry set if out of space.
; All functions clobber X, so save it if you need it.

; Maximum line length we're willing to encode (leave 16 bytes at end for END statement in immediate mode)
MAX_LINE_LENGTH = 240

; Make sure Line didn't get too big
.assert .sizeof(Line) < 256 - MAX_LINE_LENGTH, error

; Encodes a number.
; FP0 = the number to encode
; BC SAFE, DE SAFE

encode_number:
        lda     #TOKEN_NUM
        jsr     encode
        lda     lp
        cmp     #MAX_LINE_LENGTH-.sizeof(Float) ; Check if enough space for Float
        bcs     @error                  ; Nope; return with carry set
        ldy     #>line_buffer           ; High byte of line_buffer in Y
        jsr     store_fp0
        jmp     advance_lp_sizeof_float
@error:
        rts

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
        ldx     lp                      ; lp is line position but it is also the current line length
        cpx     #MAX_LINE_LENGTH-1      ; Subtract 1 for this byte
        bcs     @error                  ; If carry set (no borrow) then line length >= MAX_LINE_LENGTH-1
        sta     line_buffer,x
        inc     lp
        rts

@error:
        pla                             ; Discard the return address 
        pla     
        rts                             ; Return to the caller's caller
