; cc65 runtime
.include "zeropage.inc"

.include "basic.inc"

; Parses a number from the buffer.
; If the first character is not a number, then return an error. Otherwise, parse up to the first non-digit.
; Y = the read index
; Returns the number in AX, carry clear if ok, carry set if error

parse_number:
        jsr     skip_whitespace
        sty     tmp2            ; Save Y into tmp2; we'll use this to check if we read anything
        lda     #0              ; Intialize the value to 0
        tax
@next:
        cpy     buffer_length   ; At the end of the line yet?
        beq     @finish         ; Yes, return
        pha                     ; Save A (low byte of value)
        lda     buffer,y
        jsr     char_to_digit   ; Doesn't touch X
        sta     tmp1            ; Store the digit value in tmp1
        pla                     ; Retrieve the low byte of value
        bcs     @finish         ; If there was an error in char_to_digit, stop parsing
        iny                     ; No error, increment read index
        jsr     mul10           ; Multiply the value by 10
        clc
        adc     tmp1            ; Add tmp1
        bcc     @next           ; If carry clear then next digit
        inx                     ; Otherwise increment high byte
        jmp     @next

@finish:
        cpy     tmp1            ; Did we parse anything?
        beq     @nothing        ; Nope
        clc                     ; Clear carry to signal OK
        rts

@nothing:
        sec                     ; Set carry to signal error
        rts

; Converts the character in A into a digit.
; This function only uses A and does not touch X or Y.
; Returns the digit in A, carry clear if ok, carry set if error

char_to_digit:
        sec                     ; Set carry
        sbc     #'0'            ; Subtract '0'
        bcc     @set_carry_return   ; If we had to borrow (carry clear) then not digit
        cmp     #10             ; If we did *not* borrow (carry set) then not digit
        rts

@set_carry_return:
        sec                     ; Set carry to indicate error
        rts

; Tests the input against a keyword. The last letter of the keyword must have bit 7 set (but it is ignored
; in the comparison).
; AX = pointer to the keyword
; Y = read index into buffer
; Returns carry clear if the keyword matched, carry set if it didn't match.

parse_keyword:
        sta     ptr1            ; Keyword pointer into ptr1        
        stx     ptr1+1
        tya                     ; Use X to index the buffer in this function
        tax
        ldy     #0              ; Y will index the keyword
@compare:
        cpx     buffer_length   ; At the end of the buffer?
        beq     @not_match      ; Yep
        lda     (ptr1),y        ; Get keyword character
        and     #$7F            ; Mask out the high bit
        cmp     buffer,x        ; Compare with character from buffer
        bne     @not_match      ; It's not a match (carry flag will be uncertain)
        lda     (ptr1),y        ; Get keyword character again
        bmi     @match          ; Last character so it's a match; carry will be set from cmp above
        inx                     ; Next position
        iny
        jmp     @compare

@match:
        clc                     ; On match the carry flag will be set to have to clear it
        rts

@not_match:
        sec
        rts

; Skip past any whitespace in the buffer.
; Y = the read index

iny_skip_whitespace:
        iny
skip_whitespace:
        lda     buffer,y
        cmp     #' '
        beq     iny_skip_whitespace
        rts
