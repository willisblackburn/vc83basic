
; Functions in this module are only used when parsing program lines and are optimzed for space over speed.
; All functions write to the output buffer at index line_pos and update line_pos.
; All functions return carry clear if ok or carry set if out of space.
; All functions clobber X, so save it if you need it.

; Maximum line length we're willing to encode (leave 16 bytes at end for END statement in immediate mode)
MAX_LINE_LENGTH = 240

; Make sure Line didn't get too big
.assert .sizeof(Line) < 256 - MAX_LINE_LENGTH, error

; Encodes zero.

encode_zero:
        lda     #0

; Fall through

; Encodes a single byte.
; A = the byte to encode
; Y SAFE, BC SAFE, DE SAFE

encode_byte:
        ldx     line_pos
        cpx     #MAX_LINE_LENGTH
        raieq   ERR_LINE_TOO_LONG
        sta     line_buffer,x
        inc     line_pos
        rts
