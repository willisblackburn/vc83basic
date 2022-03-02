; cc65 runtime
.include "zeropage.inc"

.include "basic.inc"

.zeropage

; Read index.
r: .res 1

.code

; Parses a number from the buffer.
; If the first character is not a number, then return an error. Otherwise, parse up to the first non-digit.
; r = the read index
; Returns the number in AX, carry clear if ok, carry set if error

parse_number:
        jsr     skip_whitespace
        ldy     r               ; Use Y to index buffer
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
        cpy     r               ; Did we parse anything?
        beq     @nothing        ; Nope
        sty     r               ; Update read index
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
        sbc     #'0'            ; Subtract '0'; maps valid values to range 0-9 and other values to 10-255
        cmp     #10             ; Sets carry if it's in the 10-255 range
        rts

; Matches the input against names from a table.
; The last letter of each name must have bit 7 set (but it is ignored in the comparison).
; A zero byte ends the name table.
; AX = pointer to the name table
; r = read index into buffer
; Returns carry clear if the name matched and the index of the name in A, carry set if it didn't match any name.

parse_name:
        sta     ptr1            ; Name table pointer into ptr1        
        stx     ptr1+1
        lda     #0              ; Name index
        sta     tmp1            ; Maintain in tmp1
        jsr     skip_whitespace
@compare_name:
        ldx     r               ; Use X to index buffer in this function
        ldy     #0              ; Y will index the name
        sty     tmp2            ; Reset number of unmatched characters

; Compare each character of the name table entry with the input and count unmatched characters in tmp2.
; A character is matched if either we've run out of characters in the buffer or the characters don't match.
; When we find the last character in the name, if the unmatched count is zero then return that name.

@compare_byte:
        lda     (ptr1),y        ; Get name character
        beq     @fail           ; If it's 0 then out of names to match
        pha                     ; Save on the stack for later
        and     #$7F            ; Mask out the high bit
        cpx     buffer_length   ; At the end of the buffer? (TODO: add 0 to buffer instead)
        beq     @no_match       ; Yes
        cmp     buffer,x        ; Compare with character from buffer
        beq     @match          ; It matches
@no_match:
        inc     tmp2            ; Increment unmatched count
@match:
        iny                     ; Next position
        inx                     
        pla                     ; Get name character again
        bmi     @finish_name    ; Last character so it's a match; carry will be set from cmp above
        bne     @compare_byte   ; X cannot be zero so this is unconditional branch

@finish_name:
        clc                     ; Going to need carry clear no matter what, so do that now
        lda     tmp2            ; How many unmatched?
        bne     @next_name      ; Some unmatched, go to next name.
        lda     tmp1            ; Good match, return tmp1 in A
        ldx     #0
        rts

@next_name:
        inc     tmp1            ; Increment the name index
        tya                     ; Reset ptr1 to the start of this name
        adc     ptr1            ; Carry was cleared in @finish_name
        sta     ptr1
        bcc     @compare_name   ; Don't have to increment high byte
        inc     ptr1+1
        bcs     @compare_name   ; Unconditional branch

@fail:
        sec                     ; No names matched; set carry and return
        rts

; Skip past any whitespace in the buffer.
; r = the read index

skip_whitespace:
        ldy     r               ; Use Y to index buffer
@next:
        lda     buffer,y
        iny
        cmp     #' '
        beq     @next
        dey                     ; It wasn't whitespace so go back
        sty     r               ; Update read index
        rts
