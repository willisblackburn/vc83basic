.include "macros.inc"
.include "basic.inc"

; Functions to decode values from the token stream.
; Sometimes these functions will be called when one value has already been read and is in the A register;
; this will be noted.
; We don't have to worry about errors since we're decoding what we previously encoded.
; For all functions, Y is the read position in line_ptr.

; Decodes a number and returns it in AX.

decode_number:
        inc     r                       ; Increment read position to high byte 
        ldy     r                       ; Load position of high byte into Y
        inc     r                       ; Increment read one position again
        lda     (line_ptr),y            ; Load the high byte of the number
        tax                             ; Move into X
        dey                             ; Decrement Y
        lda     (line_ptr),y            ; Get the low byte of the number into A
        rts     

; Decodes a single byte and returns it in A.
; The last instruction loads A, so this function will return with the Z and N flags set accordingly.

decode_byte:
        ldy     r                       ; Read r into Y and increment
        inc     r   
        lda     (line_ptr),y            ; Load and return the byte
        rts
