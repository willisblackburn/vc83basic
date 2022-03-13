; cc65 runtime
.include "zeropage.inc"

.include "target.inc"
.include "basic.inc"

.zeropage

name_table: .res 2 ; TODO: maybe just "name"

.code

; Matches the input against names from a table.
; The last letter of each name must have bit 7 set (but it is ignored in the comparison).
; A zero byte ends the name table.
; name_table = pointer to the first entry of the name table
; r = read index into buffer (modified)
; Returns carry clear if the name matched and carry set if it didn't match any name.
; On match, returns the number of the matched name in A and the next position in the name table
; after the matched name in Y.

find_name:

@count = tmp1

        lda     #0              ; Name index
        sta     @count      
@compare_name:
        ldy     #0              ; Y will index the name
        lda     (name_table),y  ; Get name character
        beq     @error          ; If it's 0 then out of names to match
        jsr     match_character_sequence
        bcc     @match
        jsr     advance_y_next_name     ; No match, move to next entry
        inc     @count          ; Increment name count
        jmp     @compare_name

@match:
        clc                     ; Signal success
        lda     @count          ; Return number of matched name in A
        ldx     #0
        rts

@error:
        sec                     ; Signal failure
        rts

; Skips to the start of the next name in the name table. Sets name_table to the start of that rule.
; name_table = the start of the current name
; Y = the index into the rule

advance_y_next_name:
        lda     (name_table),y  ; Load current position
        tax                     ; Can clobber X since it will be reloaded from r soon
        iny                     ; Advance past
        txa                     ; Get the loaded character back to check bit 7
        bpl     advance_y_next_name     ; Keep searching if bit 7 not set
        tya                     ; Y now points to the start of the next rule
        clc                     ; Reset name_table to this position
        adc     name_table      
        sta     name_table
        bcc     @return         ; Don't have to increment high byte
        inc     name_table+1
@return:
        rts


; Matches a character sequence from the name table with characters from buffer.
; name_table = pointer to the current name table entry
; Y = the current read position in the name table entry
; r = read index into buffer (modified)
; Returns carry clear if the name matched and carry set if it didn't match any name.
; On success, Y will point to the next byte past the matched word, or will point past the first unmatched
; character on failure.

match_character_sequence:

        ldx     r               ; Load read position into X
@compare_byte:
        lda     (name_table),y  ; Get name character
        and     #$60            ; Check if it's a string literal character
        beq     @match          ; If not, then we've reached the end of the string and have a match
        lda     (name_table),y  ; Reload the character from name table
        pha                     ; Save it to check for end bit later
        and     #$7F            ; Clear bit 7, if it's set
        cmp     buffer,x        ; Compare with character from buffer
        bne     @no_match       ; Doesn't match
        iny                     ; Next position
        inx
        pla                     ; Recover the name table byte
        bpl     @compare_byte   ; If bit 7 not set then continue

; We reached a character with bit 7 set, or a non-character byte, so we have a match.
; TODO: if last character was letter, make sure next one in buffer is not letter.

@match:
        stx     r               ; Update r
        clc                     ; Signal success
        rts

@no_match:
        pla                     ; Get rid of the name table type previously saved
        sec                     ; Signal failure
        rts
