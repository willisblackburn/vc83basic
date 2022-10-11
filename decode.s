.include "macros.inc"
.include "basic.inc"

; Functions to decode values from the token stream.
; We don't have to worry about errors since we're decoding what we previously encoded.
; For all functions, lp is the read position in line_ptr.

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
        ldy     lp
        inc     lp
        lda     (line_ptr),y
        and     #$7F                    ; Clear MSB
        rts

; Decodes a single byte and returns it in A.
; The last instruction loads A, so this function will return with the Z and N flags set accordingly.

decode_byte:
        ldy     lp                      ; Read lp into Y and increment
        inc     lp  
        lda     (line_ptr),y            ; Load and return the byte
        rts
