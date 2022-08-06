.include "macros.inc"
.include "basic.inc"

; TODO: maybe call this syntax.s

.zeropage

; Pointer to current name table entry
name_ptr: .res 2
; Read position in the name table entry
n: .res 1

.code

; Matches the input against names from a table.
; Each name table entry consists of a name, which is a sequence of character bytes in the range $20-$5F,
; followed by any number of extra data bytes. The last byte of the name table entry must have bit 7 set.
; AX = pointer to the first entry of the name table; saved into name_ptr
; r = read position in buffer (updated on success)
; Returns carry clear if the name matched and carry set if it didn't match any name.
; On match, updates name_ptr to point to the matched name, and returns the number of the matched name in A and
; the next position in the name table after the matched name in Y.
; If no match, then A is the number of names in the name table and name_ptr points to the 0 at the end of the table.

find_name:
        stax    name_ptr
        lda     #0                      ; Track name table index in B
        sta     B              
@next_name:     
        ldy     #0                      ; Y is the read position in the name table entry
        lda     (name_ptr),y            ; Get name character
        beq     @error                  ; If it's 0 then out of names to match
        jsr     match_character_sequence
        bcc     @match
        inc     B                       ; Increment name table index; doesn't affect carry
        bcs     @next_name      

@error:     
        sec                             ; Signal failure
@match:     
        lda     B                       ; Return number of matched name in A
        rts

; Matches a character sequence from the name table with characters from buffer.
; name_ptr = pointer to the current name table entry
; Y = the current read position in the name table entry
; r = read position in buffer (updated on success)
; Returns carry clear if the name matched and carry set if it didn't match any name.
; On success, Y will point to the next byte past the matched word, and name_ptr will be unchanged.
; On failure, name_ptr will be set to the next name table entry.
; B SAFE

match_character_sequence:
        ldx     r                       ; Load read position into X
@next_character:        
        lda     (name_ptr),y            ; Get name character
        sta     C                       ; Store last character in C
        and     #$60                    ; Check if it's a string literal character
        beq     @non_literal
        lda     C                       ; Reload last-read character
        and     #$7F                    ; Clear bit 7, if it's set
        cmp     buffer,x                ; Compare with character from buffer
        bne     @mismatch               ; Doesn't match
        inx                             ; Next position
        iny
        lda     C                       ; Reload character once more
        bpl     @next_character         ; Keep reading characters if this isn't the last one

; We've reached a character in the name table entry with bit 7 set and everything has matched so far.
; Check for name continuation. If the name continues, then return no match. Y already points to next entry.

        jsr     check_name_continuation
        bcs     @match
        bcc     @continued_name         ; Will always branch

; We're reached a non-literal character and everything has matched so far.
; Check for name continuation. If the name continues, then advance to next entry and return no match.

@non_literal:
        jsr     check_name_continuation
        bcs     @match
@mismatch:
        jsr     advance_y_next_entry
@continued_name:
        jsr     advance_name_ptr
        sec                             ; Set carry to indicate failure
        rts     
        
@match:     
        stx     r                       ; Update r
        clc                             ; Signal success
        rts

; Checks if the character at position X in buffer is a continuation of a name at position X-1.
; We consider it a continuation if the X-1 character was a name character and the X character is also
; a name character.
; Returns carry clear if the name is a continuation, carry set if it is not.
; X SAFE, Y SAFE, BC SAFE

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

; Advances Y until it points to the next name table entry.
; name_ptr = a pointer to the current name table entry
; Y = the read position within the name table entry (updated)
; B SAFE

advance_y_next_entry:
        lda     (name_ptr),y            ; Load current position
        tax                             ; Temporarily park in X
        iny                             ; Advance past
        txa                             ; Get the loaded character back to check bit 7
        bpl     advance_y_next_entry    ; Keep searching if bit 7 not set
        rts

; Adds Y to name_ptr.
; name_ptr = a pointer to the current name table entry
; Y = the value to add, which should be the position of the next name table entry relative to this one
; B SAFE

advance_name_ptr:
        tya                             ; Y is now the offset of the next rule; add to name_ptr
        clc                             ; Add to name_ptr to get updated name_ptr
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
; and n are reset to zero.

get_name_table_entry:
        stax    name_ptr                ; Initialize name_ptr
        sty     B                       ; Track the index in B
@next_name:
        dec     B
        bmi     @found                  ; If @index is now <0 then we're done (this limits name table to 128 entries)
        ldy     #0                      ; Y is now the index into the name table entry
        lda     (name_ptr),y            ; Check if at end of name table
        beq     @not_found
        jsr     advance_y_next_entry    ; Advance Y until it points to the next entry
        jsr     advance_name_ptr        ; Add Y to name_ptr
        jmp     @next_name
@found:
        clc
        ldy     #0
        sty     n
        rts
@not_found:
        sec
        rts
        
; Extends the variable name table by adding a new name.
; This will clobber the current program state and prevent the user from using CONT to resume execution.
; The new name consists of all the name characters from buffer starting with the position in r.
; name_ptr = a pointer to the 0 at the end of the variable name table (left there by find_name)
; Returns carry clear on success or carry set on failure.
; On success, updates variable_value_table and variable_count, and returns ID of new variable in A.

add_variable:
        lda     variable_count          ; Check if too many variables already
        bmi     @fail                   ; variable_count >= 128
        ldx     r                       ; Read position in buffer
@find_end:
        inx                             ; We'll never have a zero-length name so inc first
        lda     buffer,x                ; Look for non-name character
        jsr     is_name_character
        bcc     @find_end               ; Still a name character
        txa                             ; Carry guaranteed to be set; handy!
        sta     B                       ; Store index of end of name in B
        sbc     r                       ; Subtract r to find length of name
        jsr     grow_variable_name_table    ; Increase variable_value_ptr
        bcs     @fail
        ldx     r                       ; Reload r
        ldy     #$FF                    ; Write position relative to name_ptr; init to -1 since we pre-increment
@copy:
        iny                             ; Increment to next write position in name table
        lda     buffer,x                ; Load one char       
        sta     (name_ptr),y            ; Store it
        inx
        cpx     B                       ; Check for end of name
        bne     @copy
        stx     r                       ; Update r
        ora     #$80                    ; Set high bit in last value
        sta     (name_ptr),y            ; Save it again
        iny
        lda     #0
        sta     (name_ptr),y            ; Store 0
        lda     variable_count          ; This will become the return value
        inc     variable_count          ; Add one to variable count
        clc                             ; Signal success
        rts                             

@fail:
        sec
        rts
        