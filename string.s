.include "macros.inc"
.include "basic.inc"

; Parses a string from src_ptr at index si and writes it to dst_ptr at index di.
; Stops parsing upon reaching the termination character. If the first character of the input is a double quote, then
; the termination character is also a double quote, and read_string interprets two double-quotes in the middle of the
; string as a single quote. Otherwise the termination character is a comma (',').
; Finding a NUL in the input terminates the string no matter what.
; Returns carry clear and updates si and di on success, or carry set on failure (and does not update si and di).
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
        stx     1,y                     ; Store high byte of string address
        tax                             ; Move low byte into X since I'm about to clobber A
        ora     E                       ; Check for null
        beq     @null_string            ; A is conveniently 0 for return
        inx                             ; Increment low byte of address
        stx     0,y                     ; Store low byte of string address
        bne     @skip_inc               ; Low byte didn't roll over so don't have to adjust high byte
        ldx     E                       ; High byte is in E, so re-load and re-store
        inx
        stx     1,y
@skip_inc:
        ldy     #0                      ; Length offset
        lda     (DE),y                  ; Load the length for return
@null_string:
        rts

; Allocates space for a new string on the string heap.
; A = the length of the new string (not including length byte)
; Returns the address of the new string in AX.
; BC SAFE, DE SAFE

string_alloc:
        pha                             ; Save the original length
        ldx     #0                      ; Initialize high byte of block length to 0
        clc
        adc     #STRING_EXTRA           ; Add 3 bytes to length: 1 byte for length, 2 bytes for GC relocation pointer
        bcc     @skip_inx               ; If no carry then leave high byte at 0
        inx                             ; Otherwise it's 1
@skip_inx:
        eor     #$FF                    ; Invert length and set carry in order to do string_ptr - AX
        sec                             ; This calculates proposed new value for string_ptr
        adc     string_ptr
        tay                             ; Store low byte of proposed value in Y
        txa                             ; Do the same thing with the high byte
        eor     #$FF
        adc     string_ptr+1
        tax                             ; Store high byte of proposed value in X
        pla                             ; Recover length from stack
        cpx     free_ptr+1              ; Compare high byte vs. free_ptr
        bcc     @error                  ; New string_ptr high byte < free_ptr; it's definitely an error
        bne     @string_ptr_ok          ; If it's greater then it's definitely okay
        cpy     free_ptr
        bcc     @error                  ; Less than free_ptr is an error, but >= is okay
@string_ptr_ok:
        sty     string_ptr              ; Proposed string_ptr >= free_ptr; go update it
        stx     string_ptr+1
        ldy     #0                      ; Offset of length
        sta     (string_ptr),y          ; Set the length
        ldax    string_ptr              ; Return pointer in AX
        clc                             ; Signal success
        rts

@error:
        sec
        rts
