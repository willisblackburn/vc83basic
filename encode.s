; cc65 runtime
.include "zeropage.inc"

.include "target.inc"
.include "basic.inc"

; Encodes an integer.
; AX = the integer to encode
; w = the pointer into output_buffer
; Returns carry clear if ok or carry set if out of space.

encode_int:
        pha
        ldy     w
        lda     #TOKEN_INT
        sta     output_buffer,y
        iny
        pla
        sta     output_buffer,y
        iny
        txa
        sta     output_buffer,y
        iny
        sty     w
        rts     
