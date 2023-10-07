.include "macros.inc"
.include "basic.inc"

; Matches the input against names from a table.
; Each name table entry consists of a name, which is a sequence of character bytes in the range $20-$5F,
; followed by any number of extra data bytes. The last byte of the name table entry must have bit 7 set.
; AX = pointer to the first entry of the name table; saved into name_ptr
; bp = read position in buffer (updated on success)
; Returns carry clear if the name matched and carry set if it didn't match any name.
; On match, updates name_ptr to point to the matched name, and returns the index of the matched name in A and
; the next position in the name table after the matched name in Y.
; If no match, then A is the number of names in the name table and name_ptr points to the 0 at the end of the table.
; The find_next_name entry point searches from the current name_ptr.

find_name:
        stax    name_ptr
        mva     #0, matched_name_index  ; Initialize name table index to 0
find_next_name:
        mvy     #0, np                  ; Set name table entry read position to 0
        lda     (name_ptr),y            ; Get first byte of name
        beq     @end                    ; If it's zero then we're at the end
        jsr     match_name              ; Try to match
        bcc     @match                  ; It matched; return
        jsr     advance_name_ptr        ; Move np up to the next entry
        inc     matched_name_index      ; Increment name table index
        bne     find_next_name          ; Handle the next entry (unconditional)

@end:
        sec                             ; Signal error
@match:
        lda     matched_name_index      ; Number of entries in the name table
        rts

; Matches a name found in the input buffer with characters from the name table entry.
; name_ptr = pointer to the name table entry
; np = current position within the name table entry
; name_bp = the start of the name within the buffer
; bp = the position of the first non-name character after the name
; Returns carry clear if the sequence matched, and np and bp both advance to the next position past the match.
; Returns carry set if no match; bp is unchanged.
; BC SAFE, DE SAFE

match_name:
        ldx     name_bp                 ; Load bp into x
@loop:
        jsr     read_name_table_byte    ; Read the next byte from the name table
        tay                             ; Save in Y
        bcs     @end_of_name            ; Carry set means last by had bit 7 set; end of word
        and     #$60                    ; Check if it's a literal
        beq     @end_of_name            ; Not a literal; must be the end of the name
        cpx     bp                      ; Are we out of name characters to match?
        beq     @error                  ; We have a name table character but no buffer character; match fails
        tya                             ; Get character back from Y
        cmp     buffer,x                ; Does it match the buffer character?
        bne     @error                  ; If not then fail
        inx                             ; Next buffer character
        inc     np                      
        jmp     @loop        

@end_of_name:
        cpx     bp                      ; Found end of name; are we also at end of buffer?
        bne     @error                  ; No, buffer is longer so no match
        clc                             ; Signal success
        rts
        
@error:
        sec                             ; Signal error
        rts
        
; Reads the name table byte at position np.
; If np > 0, checks the byte at position np-1 to see if it was the last character in the name table entry.
; Returns carry clear if there is another byte to read, with the byte in A.
; Returns carry set if there are no more bytes.
; X SAFE, BC SAFE, DE SAFE

read_name_table_byte:
        clc                             ; Default signal success
        ldy     np                      ; Load np
        beq     @done                   ; If zero then just return
        dey                             ; Go look at character at np-1
        lda     (name_ptr),y
        iny                             ; Increment Y so it's equal to np again
        asl     A                       ; Shift NT_END bit into carry
@done:
        lda     (name_ptr),y            ; Load next character to match
        and     #$7F                    ; Don't need NT_END bit; it's only checked here
        rts

; Advances name_ptr to the next name table entry.
; We don't know where np is when this gets called, so we start scanning from the start of the current entry
; until we find the next one.
; name_ptr = a pointer to the current name table entry (updated)
; X SAFE, BC SAFE, DE SAFE

advance_name_ptr:
        ldy     #$FF                    ; Start at -1 because we pre-increment
@loop:
        iny
        lda     (name_ptr),y            ; Load character at current position
        bpl     @loop                   ; Keep searching if bit 7 not set
        iny                             ; Skip past the last character
        tya                             ; Y is the offset of the next element
        clc                             ; Add it to name_ptr to get updated name_ptr
        adc     name_ptr            
        sta     name_ptr        
        bcc     @done                   ; Don't have to increment high byte
        inc     name_ptr+1
@done:
        rts

; Finds a name entry by its index.
; AX = pointer to the first entry in the name table
; Y = the index of the entry to find
; Returns carry clear on success, carry set on error. On success, name_ptr points to the name table entry and both Y
; and np are reset to zero.

get_name_table_entry:
        stax    name_ptr                ; Initialize name_ptr
        sty     matched_name_index      ; Track the index in matched_name_index
@next_name:
        mvy     #0, np                  ; Initialize np to 0
        dec     matched_name_index
        bmi     @found                  ; If @index is now <0 then we're done (this limits name table to 128 entries)
        lda     (name_ptr),y            ; Check if at end of name table
        beq     @not_found
        jsr     advance_name_ptr        ; Advance to the next entry
        jmp     @next_name
@found:
        clc
        rts
@not_found:
        sec
        rts
        
; Extends the variable name table by adding a new name.
; The new name consists of the characters in buffer from position name_bp to bp.
; name_ptr = a pointer to the 0 at the end of the variable name table (left there by find_name)
; Returns carry clear on success or carry set on failure.
; On success, updates variable_value_table and variable_count, and returns ID of new variable in A.

add_variable:
        sec                             ; We need carry set for SBC; set here to re-use as error bit on fail
        lda     variable_count          ; Check if too many variables already
        bmi     @fail                   ; variable_count >= 128
        lda     bp                      ; Read position in buffer
        sbc     name_bp                 ; Subtract name_bp to find length of name
        ldy     #value_table_ptr        ; Grow variable name table by moving value table pointer
        jsr     grow_a                  ; Do the grow
        bcs     @fail
        ldx     name_bp                 ; Copy from name_bp
        ldy     #0                      ; Copy to name_ptr offset 0
@next_character:
        lda     buffer,x                ; Load one character
        sta     (name_ptr),y
        inx
        iny
        cpx     bp                      ; Reached end?
        bne     @next_character
        lda     #0
        sta     (name_ptr),y            ; Store 0 to terminate the name table
        dey                             ; Back up 1
        lda     (name_ptr),y            ; Get the last name character saved to name table
        ora     #$80                    ; Set high bit in last value
        sta     (name_ptr),y            ; Save it again
        ldy     #free_ptr               ; Grow value table by 2
        lda     #2
        jsr     grow_a
        bcs     @fail
        lda     variable_count
        jsr     set_variable_value_ptr  ; variable_value_ptr points to the space for the new value
        ldy     #0                      ; Offset 0
        tya
        sta     (variable_value_ptr),y  ; Zero the new value
        iny
        sta     (variable_value_ptr),y  ; Zero the new value
        lda     variable_count          ; This will become the return value
        inc     variable_count          ; Add one to variable count
        clc                             ; Signal success
@fail:
        rts                             ; All jumps to @fail have carry set
