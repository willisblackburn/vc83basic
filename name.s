.include "macros.inc"
.include "basic.inc"

; Matches the input against names from a table.
; Each name table entry consists of a length (one byte if in the range 0-127, otherwise two bytes, high byte first),
; followed by a name, followed by any number of extra data bytes. The last byte of the name must have bit 7 set.
; AX = pointer to the first entry in the name table; saved into next_name_ptr
; match_ptr = pointer to the name to match
; Returns carry clear if the name matched and carry set if it didn't match any name.
; On match, updates name_ptr to point to the data following matched name, and returns the index of the matched name
; in A.
; If no match, then A is the number of names in the name table and name_ptr points to the 0 at the end of the table.

find_name:
        jsr     initialize_name_ptr
find_name_2:
        inc     name_index              ; Increment index
        jsr     advance_name_ptr        ; Tee up next entry
        bcs     @done
        jsr     match_name              ; Try to match
        bcs     find_name_2             ; If no match then try next one
        jsr     rebase_name_ptr         ; Advance name_ptr to point to data after name
@done:
        lda     name_index              ; Matched index or number of entries in the name table
        rts

; Matches a name found in the input buffer with characters from the name table entry.
; match_ptr = pointer to the name to match
; name_ptr = pointer to the name within the name table entry that we're going to match
; Returns carry clear if the sequence matched. Y will be left set to the length of the matched name.
; Returns carry set if no match.
; BC SAFE, DE SAFE

match_name:
        ldy     #0                      ; Start matching at position 0; also clears N flag
@next:
        lda     (name_ptr),y            ; Load next byte from name table entry
        bmi     @last                   ; This is the last character
        cmp     (match_ptr),y           ; Compare to the source name
        bne     @no_match               ; If not match then fail; if we get past this point then we're still matching
        iny
        bne     @next

@last:
        cmp     (match_ptr),y           ; One last compare
        bne     @no_match
        iny                             ; Account for matching last character
        clc                             ; Signal success
        rts
        
@no_match:
        sec                             ; Signal error
        rts

; Saves a new value (passed in AX) into name_ptr and also resets name_index to 0.
; AX = pointer to the start of the name table

initialize_name_ptr:
        stax    next_name_ptr           ; This will be copied into name_ptr
        mva     #$FF, name_index        ; Initialize name table index to -1 so first INC makes it 0
        rts

; Replaces name_ptr with next_name_ptr and advances next_name_ptr.
; next_name_ptr = a pointer to the current name table entry (updated)
; Returns carry clear if name_ptr points to a valid entry, or set if it is pointing to the end of the name table.
; BC SAFE, DE SAFE

advance_name_ptr:
        mvax    next_name_ptr, name_ptr ; Advance to next entry
        ldy     #0                      ; name_ptr index
        ldx     #0                      ; X is the first byte of the name table entry
        sec                             ; Set carry for error return if we find no more entries
        lda     (name_ptr),y            ; Load first byte of name table entry; may be single byte or high byte
        beq     advance_rebase_name_ptr_done    ; If length is zero then no more names
        bpl     @single_byte            ; High bit is clear; just add this as the low byte
        and     #$7F                    ; Clear the high bit
        tax                             ; The byte we read is the high byte
        iny
        lda     (name_ptr),y            ; It was a two-byte length, so get the low byte at Y=1
@single_byte:
        clc
        adc     next_name_ptr           ; Add AX to next_name_ptr
        sta     next_name_ptr
        txa
        adc     next_name_ptr+1
        sta     next_name_ptr+1
        iny                             ; Y is now the number of bytes in the length

; Fall through

; Rebases name_ptr by adding Y.
; name_ptr = pointer to somewhere within the current name table entry
; Y = the offset to add to name_ptr
; Always succeeds. Returns with carry clear, name_ptr updated.
; X SAFE, Y SAFE, BC SAFE, DE SAFE

rebase_name_ptr:
        tya                             ; Move offset into A and add to name_ptr
        clc                             ; Not sure if carry is set or not so clear it now
        adc     name_ptr                ; Add to name_ptr
        sta     name_ptr
        bcc     advance_rebase_name_ptr_done
        inc     name_ptr+1
        clc                             ; Clear carry for return
advance_rebase_name_ptr_done:
        rts

; Finds a variable, or adds it.
; match_ptr = pointer to the variable name
; match_length = the length of the variable
; Returns carry clear if find_name or add_variable succeeded, or carry set on error.

find_or_add_variable:
        ldax    variable_name_table_ptr
        jsr     find_name               ; Look for a variable with this name
        bcs     @not_found              ; Most common case is that it's found, so branch only if it's not
        rts                             ; Return success

@not_found:
        ldax    #.sizeof(Float)         ; Allocate space for the variable

; Fall through

; Extends the variable name table by adding a new name.
; The new name consists of the characters defined by match_ptr and match_length. These are both set in decode_name.
; The name must already end in a character with the high bit set.
; AX = the number of data bytes to allocate after the name
; name_ptr = a pointer to the 0 at the end of the variable name table (left by find_name)
; name_index = the number of names currently in the table (also left by find_name)
; Returns carry clear on success or carry set on failure.
; On return, updates name_ptr to point to the data following the new name, as if found by find_name.
add_variable:
        sec                             ; Set carry in case the variable count check fails and to add 1 for length
        ldy     name_index              ; Check if too many variables already
        bmi     @error                  ; variable_count >= 128
        adc     match_length            ; Add match_length plus 1 (carry) to get total size to allocate
        sta     B                       ; Park length low byte in B
        bcc     @skip_inx               ; No carry; don't need to increment high byte
        inx
@skip_inx:
        txa                             ; Test high byte
        beq     @single_byte_encoding   ; High byte is zero; we can use a single-byte encoding
        inc     B                       ; Else we have to use two bytes, so add one more to length
        bne     @skip_inx_2             ; Didn't roll over so don't need to INX
        inx
@skip_inx_2:
        txa                             ; Test high byte again
        bmi     @error                  ; If high bit is already set then length is too large to encode
@single_byte_encoding:
        stx     C                       ; Store high byte of the length in C
        lda     B                       ; Recover low byte; length is now in AX for call to grow, and in BC
        ldy     #free_ptr               ; Grow variable name table by moving free_ptr up
        jsr     grow                    ; Do the grow
        bcs     @error
        mvax    name_ptr, dst_ptr       ; Prepare to clear the newly-allocated entry
        ldax    BC                      ; Recover size
        jsr     clear_memory
        sta     (dst_ptr),y             ; Y will be first uncleared byte on return; clear it to terminate name table
        ldy     #0                      ; Start writing length to name_ptr starting at offset 0
        ldx     C                       ; Consider the high byte
        bne     @write_two_byte_length  ; High byte is non-zero; use two-byte encoding
        lda     B                       ; Consider the low byte again (note we are discarding the zero high byte)
        bpl     @write_length_low_byte  ; It's < 128; just use single-byte encoding
@write_two_byte_length:
        txa                             ; High byte into A
        ora     #$80                    ; Set high bit, which we know is clear because we tested it before
        sta     (name_ptr),y
        iny
        lda     B                       ; Replace A with low byte
@write_length_low_byte:
        sta     (name_ptr),y
        iny
        jsr     rebase_name_ptr         ; Add Y to name_ptr
        ldy     #0                      ; Start copying name at offset 0
@copy_next_character:
        lda     (match_ptr),y           ; Get name character
        sta     (name_ptr),y            ; Store into name table
        bmi     @copy_last
        iny
        bne     @copy_next_character

@copy_last:
        iny                             ; Last character
        jsr     rebase_name_ptr         ; Make name_ptr point past end of data
        clc                             ; Signal success
        rts

@error:
        sec                             ; Signal error
        rts
