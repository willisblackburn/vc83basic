; cc65 runtime
.include "zeropage.inc"

.include "target.inc"
.include "basic.inc"

.zeropage

name_table: .res 2
name_index: .res 1 ; TODO: maybe can be tmpN

.code

; Matches the input against names from a table.
; The last letter of each name must have bit 7 set (but it is ignored in the comparison).
; A zero byte ends the name table.
; AX = pointer to the name table
; r = read index into buffer (modified)
; Returns carry clear if the name matched and carry set if it didn't match any name.
; On match, returns the index of the name in A (and also in name_index) and the next position in the name table
; after the matched name in Y.

find_name:

        sta     name_table      ; Name table pointer into name_table        
        stx     name_table+1
        lda     #0              ; Name index
        sta     name_index      
        jsr     skip_whitespace
@compare_name:
        ldx     r               ; Use X to index buffer in this function
        ldy     #0              ; Y will index the name
        lda     (name_table),y  ; Get name character
        beq     @error          ; If it's 0 then out of names to match
        jsr     match_character_sequence
        bcc     @match
        jsr     advance_y_next_name     ; No match, move to next entry
        inc     name_index      ; Increment to next index
        jmp     @compare_name

@match:
        stx     r               ; Update read index
        clc                     ; Signal success
        lda     name_index      ; Return name index in A
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


; Matches a character sequence from the name table with characters from buffer.
; name_table = pointer to the current name table entry
; Y = the current read position in the name table entry
; r = read index into buffer (modified)
; Returns carry clear if the name matched and carry set if it didn't match any name.
; On success, Y will point to the next byte past the matched word, or will point past the first unmatched
; character on failure.

match_character_sequence:

@save_name_table_byte = tmp1

        ldx     r               ; Load read position into X
@compare_byte:
        lda     (name_table),y  ; Get name character
        sta     @save_name_table_byte
        and     #$60            ; Check if it's a string literal character
        beq     @match          ; If not, then we've reached the end of the string and have a match
        lda     @save_name_table_byte    ; Reload the character from name table
        and     #$7F            ; Clear the high bit, if it's set
        cmp     buffer,x        ; Compare with character from buffer
        bne     @no_match       ; Doesn't match
        iny                     ; Next position
        inx
        lda     @save_name_table_byte 
        bpl     @compare_byte   ; If high bit not set then continue

; We reached a character with the high bit set, or a non-character byte, so we have a match.
; TODO: if last character was letter, make sure next one in buffer is not letter.

@match:
        sty     r               ; Update r
        clc                     ; Signal success
        rts

@no_match:
        sec                     ; Signal failure
        rts
