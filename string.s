.include "macros.inc"
.include "basic.inc"

; Sets src_ptr to point to the character data for a string, and returns the length.
; AX = the address of the string
; On return, src_ptr is set to the address of the string data (or 0 if the string address was 0),
; and Y is the length of the string.
; BC SAFE, DE SAFE

set_string_src_ptr:
        ldy     #0                      ; Initialize Y to zero first
        stax    src_ptr                 ; Initialize string address
        ora     src_ptr+1               ; OR the address bytes together
        beq     @done                   ; If address was 0, return with 0 in Y for length
        lda     (src_ptr),y             ; Length into A
        tay                             ; Into Y for return
        inc     src_ptr                 ; Increment the buffer address
        bne     @done                   ; If it didn't roll over to 0 then don't increment the high byte
        inc     src_ptr+1               ; Otherwise do
@done:
        rts

; Parses a string from src_ptr at index si and writes it to dst_ptr at index di.
; Stops parsing upon reaching the termination character. If the first character of the input is a double quote, then
; the termination character is also a double quote, and read_string interprets two double-quotes in the middle of the
; string as a single quote. Otherwise the termination character is a comma (',').
; Finding a NUL in the input terminates the string no matter what.
; Returns carry clear and updates buffer_pos and line_pos on success, or carry set on failure (and does not update buffer_pos and line_pos).
; BC SAFE

read_string:
        mva     di, E                   ; Remember destination index in E to update length later
        inc     di                      ; Increment destination to make room for length
        ldy     si
        inc     si                      ; Skip over what might be a double quote
        lda     (src_ptr),y             ; Get first character
        cmp     #'"'                    ; Is first character a double quote?
        beq     @store_terminator       ; It is, use it
        lda     #','                    ; No; terminator is a comma
        dec     si                      ; Back up to treat first character as part of string
@store_terminator:
        sta     D                       ; Store terminator in D
@next:
        ldy     si
        lda     (src_ptr),y             ; Get next source character
        beq     @finish                 ; Was zero, definitely finished
        cmp     D                       ; Was it the terminator?
        bne     @not_terminator         ; Nope
        cmp     #'"'                    ; Was the terminator also double quote?
        bne     @finish                 ; Nope; we're finished
        inc     si                      ; Always skip over a double quote
        iny                             ; Increment Y as well in order to test the next character
        cmp     (src_ptr),y             ; Is it also a double quote?
        bne     @finish                 ; Nope, just finish; si points to character after double quote
@not_terminator:
        inc     si                      ; Move source index past the character
        ldy     di
        inc     di
        sta     (dst_ptr),y             ; Store in output
        bne     @next                   ; Unconditional

@finish:
        clc                             ; Subtract E from dp to get string length; clear carry subtracts 1 for length
        lda     di
        sbc     E
        ldy     E
        sta     (dst_ptr),y             ; Store length
        clc                             ; Signal success
        rts
