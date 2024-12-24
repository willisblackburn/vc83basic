.include "macros.inc"
.include "basic.inc"

; Loads a string into one of the two S registers.
; Returns length in A and a pointer to the string data in the selected S register: either S0 for load_s0, or the
; register identified by X for load_sx.
; AY = a pointer to the string to load
; BC SAFE

load_s0:
        ldx     #S0
load_sx:
        stay    DE                      ; DE is a temporary pointer
        sty     1,x                     ; Store high byte of string address
        tay                             ; Move low byte into Y since I'm about to clobber A
        ora     E                       ; Check for null
        beq     @null_string            ; A is conveniently 0 for return
        iny                             ; Increment low byte of address
        sty     0,x                     ; Store low byte of string address
        bne     @skip_inc               ; Low byte didn't roll over so don't have to adjust high byte
        ldy     E                       ; High byte is in E, so re-load and re-store
        iny
        sty     1,x
@skip_inc:
        ldy     #0                      ; Length offset
        lda     (DE),y                  ; Load the length for return
@null_string:
        rts

; Parses a string from src_ptr and writes it to a new string allocated from string space.
; Stops parsing upon reaching the termination character. If the first character of the input is a double quote, then
; the termination character is also a double quote, and read_string interprets two double-quotes in the middle of the
; string as a single quote. Otherwise the termination character is a comma (',').
; Finding a NUL in the input terminates the string no matter what.
; AX = the buffer address (stored in src_ptr)
; Y = the starting offset
; Returns the address of the new string in AX and the last read position in Y, carry clear if ok, carry set if error.

read_string:
        stax    src_ptr                 ; Store src_ptr
        sty     B                       ; Read position relative to src_ptr
        lda     #0                      ; Allocate 0-byte string
        jsr     string_alloc            ; Don't care about the address of this string
        bcs     @done
        lda     #255                    ; Allocate second 255-byte string
        jsr     string_alloc
        bcs     @done
        ldy     B
        lda     (src_ptr),y             ; Get first character
        iny                             ; Skip past it in case it's a double quote
        cmp     #'"'                    ; Is first character a double quote?
        beq     @store_terminator       ; It is, use it
        lda     #','                    ; No; terminator is a comma
        dey                             ; Move back so we read it again
@store_terminator:
        sta     D                       ; Store terminator in D
        sty     B                       ; Update read offset in B
        lda     #1
        sta     C                       ; Initialize write position relative to string_ptr
@next:
        ldy     B                       ; Read offset
        lda     (src_ptr),y             ; Get next source character
        beq     @finish                 ; Was zero, definitely finished
        cmp     D                       ; Was it the terminator?
        bne     @not_terminator         ; Nope
        cmp     #'"'                    ; Was the terminator also double quote?
        bne     @finish                 ; Nope; we're finished
        inc     B                       ; Always skip over this quote
        iny                             ; Increment Y in order to check the next character
        cmp     (src_ptr),y             ; Is it also a double quote?
        bne     @finish                 ; Nope, just finish; B points to character after double quote
@not_terminator:
        ldy     C                       ; Write offset
        sta     (string_ptr),y          ; Store in output
        inc     B                       ; Increment read and write offset
        inc     C
        jmp     @next

; When we get here, B always points to the next read position, and the length of the string is in C.

@finish:
        ldy     #0                      ; Offset 0 relative to string_ptr is the length of the string we just read
        ldx     C                       ; Length of the string (plus one for length byte)
        dex                             ; Remove length byte
        txa
        sta     (string_ptr),y          ; Store length
        clc                             ; Add length to string_ptr to get address of second string less STRING_EXTRA
        adc     string_ptr
        sta     D                       ; Store that pointer in DE
        lda     string_ptr+1
        adc     #0
        sta     E
        ldy     #STRING_EXTRA           ; Add STRING_EXTRA via Y
        txa                             ; Length
        eor     #$FF                    ; Invert bits to produce 255 - length
        sta     (DE),y                  ; Store it
        ldax    string_ptr              ; Return pointer to string in AX
        ldy     B                       ; Return read position in Y
@done:
        rts                             ; If we reached here via @finish, carry guaranteed to be clear by ADC

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
