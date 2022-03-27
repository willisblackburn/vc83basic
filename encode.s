; cc65 runtime
.include "zeropage.inc"

.include "target.inc"
.include "basic.inc"

; Functions in this module are only used when parsing program lines and are optimzed for space over speed.
; All functions write to the output buffer at index w and update w.
; All functions return carry clear if ok or carry set if out of space.
; All function clobber Y, so save it if you need it.
; Functions may use regsave for temporary storage.

; Encodes a number.
; AX = the integer to encode

encode_number:
        sta     regsave
        lda     #TOKEN_INT
        jsr     encode
        lda     regsave
        jsr     encode
        txa
        jsr     encode
        rts     

; Encodes a single byte.
; A = the byte to encode

encode_byte:
        jsr     encode
        rts

; Encodes a single byte and returns to the caller's caller on failure.
; A = the byte to encode
; On error, pops the return address off the stack and then does RTS to the caller's return address. This is so
; the caller doesn't have to handle the error. Of course this implies the caller *can't* handle the error.
; Also, the caller can't have anything other than its own return address on the stack when calling this function.

encode:
        ldy     w
        sta     output_buffer,y
        inc     w
        beq     @error
        clc
        rts

@error:
        sec
        pla                     ; Discard the return address 
        pla
        rts                     ; Return to the caller's caller



        

