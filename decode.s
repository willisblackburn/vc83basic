; cc65 runtime
.include "zeropage.inc"

.include "target.inc"
.include "basic.inc"

; Functions to decode values from the token stream.
; Sometimes these functions will be called when one value has already been read and is in the A register;
; this will be noted.
; We don't have to worry about errors since we're decoding what we previously encoded.
; For all functions, Y is the read position in line_ptr.

; Decodes a number and returns it in AX.

decode_number:
        ldy     r                       ; Load read position into Y
        iny                             ; Increment Y
        lda     (line_ptr),y            ; Load the high byte of the number
        tax                             ; Move into X
        dey                             ; Decrement Y
        lda     (line_ptr),y            ; Get the low byte into A
        iny
        iny                             ; Increment Y to the next position
        sty     r                       ; Update read position
        rts     
