.include "macros.inc"
.include "basic.inc"

; Loads a string into one of the two S registers.
; Returns length in A and a pointer to the string data in the selected S register: either S0 for load_s0, or S1
; for load_s1.
; AY = a pointer to the string to load
; DE SAFE

load_s1:
        ldx     #S1
        bne     load_s        
load_s0:
        ldx     #S0
load_s:
        stay    BC                      ; BC is a temporary pointer
        sty     1,x                     ; Store high byte of string address
        tay                             ; Move low byte into Y since I'm about to clobber A
        ora     C                       ; Check for null
        beq     @null_string            ; A is conveniently 0 for return
        iny                             ; Increment low byte of address
        sty     0,x                     ; Store low byte of string address
        bne     @skip_inc               ; Low byte didn't roll over so don't have to adjust high byte
        ldy     C                       ; High byte is in C, so re-load and re-store
        iny
        sty     1,x
@skip_inc:
        ldy     #0                      ; Length offset
        lda     (BC),y                  ; Load the length for return
@null_string:
        rts

; Parses a string from read_ptr and writes it to a new string allocated from string space.
; Stops parsing upon reaching the termination character. If the first character of the input is a double quote, then
; the termination character is also a double quote, and read_string interprets two double-quotes in the middle of the
; string as a single quote. Otherwise the termination character is a comma (',').
; Finding a NUL in the input terminates the string no matter what.
; AX = the buffer address (stored in read_ptr)
; Y = the starting offset
; Leaves string_ptr pointing at the string and the last read position in Y, carry clear if ok, carry set if error.

read_string:
        stax    read_ptr                ; Store read_ptr
        jsr     find_printable_character    ; Skip any whitespace        
        sty     D                       ; Read position relative to read_ptr
        ldax    #(255 + STRING_EXTRA + STRING_EXTRA)    ; Allocate space for 2 strings with total length of 255
        jsr     string_alloc_memory
        bcs     @done
        ldy     D
        lda     (read_ptr),y            ; Get first character
        iny                             ; Skip past it in case it's a double quote
        cmp     #'"'                    ; Is first character a double quote?
        beq     @store_terminator       ; It is, use it
        lda     #','                    ; No; terminator is a comma
        dey                             ; Move back so we read it again
@store_terminator:
        sta     B                       ; Store terminator in B
        sty     D                       ; Update read offset in D
        lda     #1
        sta     E                       ; Initialize write position in E
@next:
        ldy     D                       ; Read offset
        lda     (read_ptr),y            ; Get next source character
        beq     @finish                 ; Was zero, definitely finished
        cmp     B                       ; Was it the terminator?
        bne     @not_terminator         ; Nope
        cmp     #'"'                    ; Was the terminator also double quote?
        bne     @finish                 ; Nope; we're finished
        inc     D                       ; Always skip over this quote
        iny                             ; Increment Y in order to check the next character
        cmp     (read_ptr),y            ; Check second double quote (if present cannot have EOT set)
        bne     @finish                 ; Nope, just finish; D points to character after double quote
@not_terminator:
        ldy     E                       ; Write offset
        sta     (string_ptr),y          ; Store in output
        inc     D                       ; Increment read and write offset
        inc     E
        jmp     @next

; When we get here, D always points to the next read position, and the length of the string is in E.

@finish:
        ldy     #0                      ; Offset 0 relative to string_ptr is the length of the string we just read
        ldx     E                       ; Length of the string (plus one for length byte)
        dex                             ; Remove length byte
        txa
        sta     (string_ptr),y          ; Store length
        clc                             ; Add length to string_ptr to get address of second string less STRING_EXTRA
        adc     string_ptr
        sta     B                       ; Store that pointer in BC
        lda     string_ptr+1
        adc     #0
        sta     C
        ldy     #STRING_EXTRA           ; Add STRING_EXTRA via Y
        txa                             ; Length
        eor     #$FF                    ; Invert bits to produce 255 - length
        sta     (BC),y                  ; Store it
        ldy     D                       ; Return read position in Y
@done:
        rts                             ; If we reached here via @finish, carry guaranteed to be clear by ADC

; Allocates a new string on the string heap.
; A = the length of the new string (not including length byte)
; Returns the address of the new string in string_ptr and in AY (to make it easy to pass to load_s0/s1).
; BC SAFE, DE SAFE

string_alloc:
        pha                             ; Remember the requested size in order to set it into string later
        ldx     #0                      ; Initialize high byte of block length to 0
        clc
        adc     #STRING_EXTRA           ; Add 3 bytes to length: 1 byte for length, 2 bytes for GC relocation pointer
        bcc     @skip_inx               ; If no carry then leave high byte at 0
        inx                             ; Otherwise it's 1
@skip_inx:
        jsr     string_alloc_memory     ; Allocate memory
        pla                             ; Get size we saved earlier
        bcs     @error                  ; Allocation failed
        ldy     #0
        sta     (string_ptr),y          ; Set the length of the allocated string
@error:
        lday    string_ptr              ; Return pointer in AY
        rts

; Allocates memory for a new string on the string heap. Called from string_alloc with the total amount of memory
; needed for the string, which is the string length plus STRING_EXTRA bytes of overhead.
; AX = the memory required for the new string
; BC SAFE, DE SAFE

string_alloc_memory:
        eor     #$FF                    ; Invert length and set carry in order to do string_ptr - AX
        sec                             ; This calculates proposed new value for string_ptr
        adc     string_ptr
        tay                             ; Store low byte of proposed value in Y
        txa                             ; Do the same thing with the high byte
        eor     #$FF
        adc     string_ptr+1
        tax                             ; Store high byte of proposed value in X
        cpx     free_ptr+1              ; Compare high byte vs. free_ptr
        bcc     @error                  ; New string_ptr high byte < free_ptr; it's definitely an error
        bne     @string_ptr_ok          ; If it's greater then it's definitely okay
        cpy     free_ptr
        bcc     @error                  ; Less than free_ptr is an error, but >= is okay
@string_ptr_ok:
        sty     string_ptr              ; Proposed string_ptr >= free_ptr; go update it
        stx     string_ptr+1
        clc                             ; Signal success
        rts

@error:
        sec                             ; Because math @error is reached from BCC so have to set carry
        rts
