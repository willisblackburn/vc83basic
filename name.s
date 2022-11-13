.include "macros.inc"
.include "basic.inc"

; TODO: maybe call this syntax.s

.zeropage

; Pointer to current name table entry
name_ptr: .res 2
; Read position in the name table entry
np: .res 1

.code

; Matches the input against names from a table.
; Each name table entry consists of a name, which is a sequence of character bytes in the range $20-$5F,
; followed by any number of extra data bytes. The last byte of the name table entry must have bit 7 set.
; AX = pointer to the first entry of the name table; saved into name_ptr
; bp = read position in buffer (updated on success)
; Returns carry clear if the name matched and carry set if it didn't match any name.
; On match, updates name_ptr to point to the matched name, and returns the index of the matched name in A and
; the next position in the name table after the matched name in Y.
; If no match, then A is the number of names in the name table and name_ptr points to the 0 at the end of the table.
; The find_next_name entry point searches from the current name_ptr. The caller must set X to the index of the
; starting name table entry.

find_name:
        stax    name_ptr
        ldx     #0                      ; Initialize name table index to 0
find_next_name:
        stx     B                       ; Track name table index in B
        jsr     skip_whitespace         ; Skip any whitespace in the buffer
@loop_entry:
        mvy     #0, np                  ; Set name table entry read position to 0
        lda     (name_ptr),y            ; Get first byte of name
        beq     @end                    ; If it's zero then we're at the end
        jsr     match_character_sequence    ; Try to match
        bcc     @match                  ; It matched; return
        jsr     advance_name_ptr        ; Move np up to the next entry
        inc     B                       ; Increment name table index
        bne     @loop_entry             ; Handle the next entry (unconditional)

@end:
        sec                             ; Signal error
@match:
        lda     B                       ; Number of entries in the name table
        rts

; Matches a sequence of character literals from the name table entry with buffer.
; name_ptr = pointer to the name table entry
; np = current position within the name table entry
; bp = position within buffer
; Returns carry clear if the sequence matched, and np and bp both advance to the next position past the match.
; Returns carry set if no match; bp is unchanged.
; BC SAFE, DE SAFE

match_character_sequence:
        ldx     bp                      ; Load bp into x
@loop:
        jsr     read_name_table_byte    ; Read the next byte from the name table
        bcs     @check_continuation     ; Last byte was the last; np is now at next entry
        cmp     buffer,x                ; Compare with buffer
        bne     @no_match               ; They didn't match; this may be because the byte is a directive
        inx                             ; Next buffer position
        inc     np                      ; Next name table entry position
        bne     @loop                   ; Unconditional

@no_match:
        lda     (name_ptr),y            ; Read character from name table again
        and     #$60                    ; Check if it's a directive (not a literal, x00x xxxx)
        bne     @error                  ; Not a directive, just a non-matching character
@check_continuation:
        jsr     check_name_continuation ; Check if the name continues
        bcc     @error                  ; It does continue so this is not a match
        stx     bp                      ; Update bp
        clc                             ; Signal success
        rts
        
@error:
        sec                             ; Signal error
        rts

; Reads the name table byte at position np.
; If np > 0, checks the byte at position np-1 to see if it was the last character in the name table entry.
; Returns carry clear if there is another byte to read, with the byte in A.
; Returns carry set if there are no more bytes.

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

; Checks if the character at position X in buffer is a continuation of a name at position X-1.
; We consider it a continuation if the X-1 character was a name character and the X character is also
; a name character.
; Returns carry clear if the name is a continuation, carry set if it is not.
; X SAFE, Y SAFE, BC SAFE, DE SAFE

check_name_continuation:
        lda     buffer-1,x              ; Get last matched character
        jsr     is_name_character
        bcs     @done                   ; Was not a name character, don't need to check the next one
        lda     buffer,x                ; Get this character
        jsr     is_name_character
@done:
        rts

; Checks if the character A is a name character. A name character is 'A'-'Z', '0'-'9', or '$'.
; Returns carry clear if it is, carry set if not.
; X SAFE, Y SAFE, BC SAFE, DE SAFE

is_name_character:
        sec                             ; Prepare for subtract
        sbc     #'$'                    ; First check '$' case        
        cmp     #1                      ; Sets carry if char was >'$'
        bcc     @done                   ; It was '$'
        sbc     #'0'-'$'                ; Check range 0-9
        cmp     #10                     ; Sets carry if char was >'9'
        bcc     @done                   ; It was in range 0-9
        sbc     #'A'-'0'                ; Check range 'A'-'Z'
        cmp     #26                     ; Sets carry if char was >'Z'
@done:      
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
        sty     B                       ; Track the index in B
@next_name:
        mvy     #0, np                  ; Initialize np to 0
        dec     B
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
; The new name consists of all the name characters from buffer starting with the position in bp.
; name_ptr = a pointer to the 0 at the end of the variable name table (left there by find_name)
; Returns carry clear on success or carry set on failure.
; On success, updates variable_value_table and variable_count, and returns ID of new variable in A.

add_variable:
        lda     variable_count          ; Check if too many variables already
        bmi     @fail                   ; variable_count >= 128
        ldx     bp                      ; Read position in buffer
@find_end:
        inx                             ; We'll never have a zero-length name so inc first
        lda     buffer,x                ; Look for non-name character
        jsr     is_name_character
        bcc     @find_end               ; Still a name character
        txa                             ; Carry guaranteed to be set; handy!
        sbc     bp                      ; Subtract bp to find length of name
        ldy     #value_table_ptr        ; Grow variable name table by moving value table pointer
        jsr     expand_a                ; Do the expand
        bcs     @fail
        ldy     #free_ptr               ; Grow value table by 2
        lda     #2
        jsr     expand_a
        bcs     @fail
        lda     variable_count
        jsr     set_variable_value_ptr  ; variable_value_ptr points to the space for the new value
        ldy     #0                      ; Offset 0
        tya
        sta     (variable_value_ptr),y  ; Zero the new value
        iny
        sta     (variable_value_ptr),y  ; Zero the new value
        ldx     bp                      ; Reload read position
        ldy     #$FF                    ; Write position relative to name_ptr; init to -1 since we pre-increment
@copy:
        lda     buffer,x                ; Load one char
        jsr     is_name_character       ; Do the test again to check for end of name
        bcs     @terminate              ; Not a name character; Y points to the last name character we wrote       
        iny                             ; Increment to next write position in name table
        lda     buffer,x                ; Transfer charater
        sta     (name_ptr),y            ; to name table
        inx                             ; Skip to next character
        jmp     @copy

@terminate:
        stx     bp                      ; X points to first non-name character, reset bp to that point
        lda     (name_ptr),y            ; Get the last name character saved to name table
        ora     #$80                    ; Set high bit in last value
        sta     (name_ptr),y            ; Save it again
        iny
        lda     #0
        sta     (name_ptr),y            ; Store 0 to terminate the name table
        lda     variable_count          ; This will become the return value
        inc     variable_count          ; Add one to variable count
        clc                             ; Signal success
        rts                             

@fail:
        sec
        rts
        