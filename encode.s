; cc65 runtime
.include "zeropage.inc"

.include "target.inc"
.include "basic.inc"

; Functions in this module are only used when parsing program lines and are optimzed for space over speed.
; All functions write to the output buffer at index w and update w.
; All functions return carry clear if ok or carry set if out of space.
; All functions clobber X, so save it if you need it.

; Encodes a number.
; AX = the integer to encode
; Y SAFE

encode_number:
        sta     regsave
        stx     regsave+1
        lda     #TOKEN_INT
        jsr     encode
        lda     regsave
        jsr     encode
        lda     regsave+1
        jsr     encode
        rts     

; Encodes a variable by its ID.
; A = the variable ID
; Y SAFE

encode_variable:
        ora     #$80                    ; Variables are encoded with the high bit set
        jsr     encode
        rts

; Encodes a single byte.
; A = the byte to encode
; Y SAFE

encode_byte:
        jsr     encode
        rts

; Encodes a single byte and returns to the caller's caller on failure.
; A = the byte to encode
; On error, pops the return address off the stack and then does RTS to the caller's return address. This is so
; the caller doesn't have to check error status after encoding each byte error. Of course this implies the caller
; *can't* handle the error. Also, the caller can't have anything other than its own return address on the stack when
; calling this function.
; Y SAFE

encode:
        ldx     w
        sta     output_buffer,x
        inc     w
        beq     @error
        clc
        rts

@error:
        pla                             ; Discard the return address 
        pla     
        sec
        rts                             ; Return to the caller's caller



        

