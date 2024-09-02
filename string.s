.include "macros.inc"
.include "basic.inc"

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

; Loads a string into one of the two S registers.
; Returns length in A and a pointer to the string data in the selected S register: either S0 for load_s0, or the
; register identified by Y for load_sy.
; AX = a pointer to the string to load
; BC SAFE

load_s0:
        ldy     #S0
load_sy:
        stax    DE                      ; DE is a temporary pointer
        sec
        adc     #0                      ; Move past length byte
        sta     0,y                     ; Set low byte of string pointer
        bcc     @skip_inx
        inx                             ; Increment high byte of address
@skip_inx:
        stx     1,y                     ; High byte of string pointer
        ldy     #0                      ; Length offset
        lda     (DE),y                  ; Load the length for return
        rts
