; cc65 runtime
.include "zeropage.inc"

.include "basic.inc"

.zeropage

; Read position in buffer
r: .res 1

.code

; Reads a number from the buffer.
; If the first character is not a number, then return an error. Otherwise, read up to the first non-digit.
; r = the read position in buffer
; Returns the number in AX, carry clear if ok, carry set if error

read_number:

@digit_value = tmp1

        jsr     skip_whitespace
        ldy     r               ; Use Y to index buffer (since AX will hold the number)
        lda     #0              ; Intialize the value to 0
        tax
@next:
        cpy     buffer_length   ; At the end of the line yet?
        beq     @finish         ; Yes, return
        pha                     ; Save A (low byte of value)
        lda     buffer,y
        jsr     char_to_digit   ; X SAFE function
        sta     @digit_value    ; Store the digit value
        pla                     ; Retrieve the low byte of value
        bcs     @finish         ; If there was an error in char_to_digit, stop parsing
        iny                     ; No error, increment read position
        jsr     mul10           ; Multiply the value by 10
        clc
        adc     @digit_value    ; Add the digit value
        bcc     @next           ; If carry clear then next digit
        inx                     ; Otherwise increment high byte
        jmp     @next

@finish:
        cpy     r               ; Did we parse anything?
        beq     @nothing        ; Nope
        sty     r               ; Update read position
        clc                     ; Clear carry to signal OK
        rts

@nothing:
        sec                     ; Set carry to signal error
        rts

; Converts the character in A into a digit.
; Returns the digit in A, carry clear if ok, carry set if error
; X SAFE, Y SAFE

char_to_digit:
        sec                     ; Set carry
        sbc     #'0'            ; Subtract '0'; maps valid values to range 0-9 and other values to 10-255
        cmp     #10             ; Sets carry if it's in the 10-255 range
        rts

; Tests the input against a keyword. The last letter of the keyword must have bit 7 set (but it is ignored
; in the comparison).
; AX = pointer to the keyword
; r = the read position in buffer
; Returns carry clear if the keyword matched, carry set if it didn't match.

parse_keyword:

@keyword_ptr = ptr1

        sta     @keyword_ptr    ; Keyword pointer into @keyword_ptr        
        stx     @keyword_ptr+1
        jsr     skip_whitespace
        ldx     r               ; Use X to index buffer in this function
        ldy     #0              ; Y will index the keyword
@compare:
        cpx     buffer_length   ; At the end of the buffer?
        beq     @not_match      ; Yep
        lda     (@keyword_ptr),y    ; Get keyword character
        and     #$7F            ; Mask out the high bit
        cmp     buffer,x        ; Compare with character from buffer
        bne     @not_match      ; It's not a match (carry flag will be uncertain)
        lda     (@keyword_ptr),y    ; Get keyword character again
        bmi     @match          ; Last character so it's a match; carry will be set from cmp above
        inx                     ; Next position
        iny                     
        jmp     @compare

@match:
        inx                     ; Move past matched character
        stx     r               ; Update read position
        clc                     ; On match the carry flag will be set to have to clear it
        rts

@not_match:
        sec
        rts

; Skip past any whitespace in the buffer.
; This function is NOT exported because we want other modules to call parsing funtions, not this function.
; r = the read position (modified)
; Y SAFE

skip_whitespace:
        ldx     r               ; Use X to index buffer
@next:
        lda     buffer,x
        inx
        cmp     #' '
        beq     @next
        dex                     ; It wasn't whitespace so go back
        stx     r               ; Update read position
        rts
