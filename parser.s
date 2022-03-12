; cc65 runtime
.include "zeropage.inc"

.include "basic.inc"

.zeropage

; Read index.
r: .res 1
; Write index.
w: .res 1

name_table = ptr1
name_index = tmp1
save_name_table_byte = tmp4     ; parse_name
digit_value = tmp1              ; parse_number

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
        sta     digit_value     ; Store the digit value
        pla                     ; Retrieve the low byte of value
        bcs     @finish         ; If there was an error in char_to_digit, stop parsing
        iny                     ; No error, increment read index
        jsr     mul10           ; Multiply the value by 10
        clc
        adc     digit_value     ; Add the digit value
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

; Parses and tokenizes a statement.
; The last byte of the buffer should be 0, which won't match anything. This avoids the need to keep checking
; the buffer length.
; AX = pointer to the syntax rule table.
; r = read index into the bffer
; Returns carry clear if the input matched a rule and the index of that rule in A, 
; or carry set if it didn't match any syntax rule.

parse_syntax:
        sta     ptr1            ; Syntax table pointer into ptr1        
        stx     ptr1+1
        ldy     #2
        lda     (ptr1),y        ; High byte of signature table address
        sta     ptr2+1          ; Store into ptr2
        dey        
        lda     (ptr1),y        ; Low byte
        sta     ptr2            
        clc
        adc     #2              ; Advance ptr1 past the signature table address
        sta     ptr1
        txa                     ; High byte is still in X
        adc     #0              ; Add the carry to it
        sta     ptr1+1          ; Store back
        lda     #0              ; Name index
        sta     tmp1            ; Maintain in tmp1
@next_syntax_rule:
        ldx     r               ; Use X to index buffer
        ldy     #0              ; Y will index the syntax rule pointed to by ptr1
        sty     tmp2            ; tmp2 is the current signature table entry
        lda     (ptr1),y        ; See what we have
        beq     @fail           ; If it was 0 then we've reached the end of the table
        iny                     ; Advance index
        pha                     ; Save the value on the stack; we'll restore to check end of rule bit later
        and     #$7F            ; 
;        bit     #$60            ; Is it the start of a string literal?
        bne     @not_literal    ; No
@next_literal:
        cmp     buffer,x        ; Compare literal 
        inx
        



@not_literal:


        sty     tmp3            ; Park Y in tmp3 and re-use Y to access the signature table
        ldy     tmp2
        and     #$07            ; Low 3 bits are the number of signature table entries to read
        beq     @skip_arguments ; No arguments (this is the mechanism that )
        sta     tmp4            ; tmp4 is the number of signature table arguments to read
@next_argument:
        beq     @finish_arguments ; No more arguments
        



        dec     tmp4            ; Decrement the number of signature table entries

@skip_arguments:

@finish_arguments:




        jsr     parse_string_literal    ; Try to parse as a string literal
        

@fail:
        sec                     ; Set carry to indicate failure
        rts


parse_string_literal:
        rts

parse_arguments:
        rts



; Matches the input against names from a table.
; The last letter of each name must have bit 7 set (but it is ignored in the comparison).
; A zero byte ends the name table.
; AX = pointer to the name table
; r = read index into buffer (updated on success)
; Returns carry clear if the name matched and carry set if it didn't match any name.
; On match, returns the index of the name in A and the next position in the name table after the matched name in Y.

parse_name:
        sta     name_table      ; Name table pointer into ptr1        
        stx     name_table+1
        lda     #0              ; Name index
        sta     name_index      
        jsr     skip_whitespace
@compare_name:
        ldx     r               ; Use X to index buffer in this function
        ldy     #0              ; Y will index the name

; Compare each character of the name table entry with the input.

@compare_byte:
        lda     (name_table),y  ; Get name character
        beq     @fail           ; If it's 0 then out of names to match
        sta     save_name_table_byte
        and     #$60            ; Check if it's a string literal character
        beq     @match          ; If not, then we've reached the end of the string and have a match
        lda     save_name_table_byte    ; Reload the character from name table
        and     #$7F            ; Clear the high bit, if it's set
        cmp     buffer,x        ; Compare with character from buffer
        bne     @no_match       ; Doesn't match
        iny                     ; Next position
        inx
        lda     save_name_table_byte 
        bpl     @compare_byte   ; If high bit not set then continue

; We reached a character with the high bit set, or a non-character byte, so we have a match.
; TODO: if last character was letter, make sure next one in buffer is not letter.

@match:
        stx     r               ; Update read index
        clc                     ; Signal success
        lda     name_index      ; Return name index in A
        ldx     #0
        rts

; No match; either ran out of buffer bytes or found one that didn't match the name.
; Advance to the next name table entry.

@no_match:
        jsr     advance_y_next_name
        inc     name_index      ; Increment to next index
        jmp     @compare_name

@fail:
        sec                     ; Signal failure
        rts

; Skips to the start of the next name in the name table. Sets name_table to the start of that rule.
; name_table = the start of the current name
; Y = the index into the rule

advance_y_next_name:
        lda     (name_table),y  ; Load current position
        tax                     ; Can clobber X since it will be reloaded from r soon
        iny                     ; Advance past
        txa                     ; Get the loaded character back to check the high bit
        bpl     advance_y_next_name     ; Keep searching if high bit not set
        tya                     ; Y now points to the start of the next rule
        clc                     ; Reset name_table to this position
        adc     name_table      
        sta     name_table
        bcc     @return         ; Don't have to increment high byte
        inc     name_table+1
@return:
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
