.include "macros.inc"
.include "basic.inc"

; Matches the input against names from a table.
; Each name table entry consists of a length (one byte if in the range 0-127, otherwise two bytes, high byte first),
; followed by a name, followed by any number of extra data bytes. The last byte of the name must have bit 7 set.
; AX = pointer to the first entry in the name table; saved into next_name_ptr
; decode_name_ptr = pointer to the name to match
; Returns carry clear if the name matched and carry set if it didn't match any name.
; On match, updates name_ptr to point to the data following matched name, and returns the index of the matched name
; in A.
; If no match, then A is the number of names in the name table and name_ptr points to the 0 at the end of the table.

find_name:
        stax    next_name_ptr           ; This will be copied into name_ptr
        mva     #$FF, name_index        ; Initialize name index to -1 so first INC makes it 0
@next:
        inc     name_index              ; Increment index
        jsr     advance_name_ptr        ; Tee up next name
        bcs     @done
        jsr     match_name              ; Try to match
        bcs     @next                   ; If no match then try next one
        jsr     rebase_name_ptr         ; Advance name_ptr to point to data after name
@done:
        lda     name_index              ; Matched index or number of entries in the name table
        rts

; Matches a name found in the input buffer with characters from the name table entry.
; decode_name_ptr = pointer to the name to match
; name_ptr = pointer to the name within the name table entry that we're going to match
; Returns carry clear if the sequence matched. Y will be left set to the length of the matched name.
; Returns carry set if no match.
; BC SAFE, DE SAFE

match_name:
        ldy     #0                      ; Start matching at position 0; also clears N flag
@next:
        lda     (name_ptr),y            ; Load next byte from name table entry
        bmi     @last                   ; This is the last character
        cmp     (decode_name_ptr),y     ; Compare to the source name
        bne     @no_match               ; If not match then fail; if we get past this point then we're still matching
        iny
        bne     @next

@last:
        cmp     (decode_name_ptr),y     ; One last compare
        bne     @no_match
        iny                             ; Account for matching last character
        clc                             ; Signal success
        rts
        
@no_match:
        sec                             ; Signal error
        rts
        
; Replaces name_ptr with next_name_ptr and advances next_name_ptr.
; next_name_ptr = a pointer to the current name table entry (updated)
; Returns carry clear if name_ptr points to a valid entry, or set if it is pointing to the end of the name table.
; BC SAFE, DE SAFE

advance_name_ptr:
        mvax    next_name_ptr, name_ptr ; Advance to next entry
        ldy     #0                      ; name_ptr index
        sec                             ; Set carry for error return if we find no more entries
        lda     (name_ptr),y            ; Load length byte from name table entry
        beq     advance_rebase_name_ptr_done    ; If length is zero then no more names
        clc
        adc     next_name_ptr           ; Add length to next_name_ptr
        sta     next_name_ptr
        bcc     @skip_inc
        inc     next_name_ptr+1
@skip_inc:
        iny

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
; decode_name_ptr = pointer to the variable name
; decode_name_length = the length of the variable
; Returns carry clear if find_name or add_variable succeeded, or carry set on error.

find_or_add_variable:
        ldax    variable_name_table_ptr
        jsr     find_name               ; Look for a variable with this name
        bcs     add_variable            ; Most common case is that it's found, so branch only if it's not
        rts                             ; Return success

; Fall through

; Extends the variable name table by adding a new name.
; The new name consists of the characters defined by decode_name_ptr and decode_name_length.
; These are both set in decode_name. The name must already end in a character with the high bit set.
; name_ptr = a pointer to the 0 at the end of the variable name table (left by find_name)
; Returns carry clear on success or carry set on failure.
; On return, updates name_ptr to point to the data following the new name, as if found by find_name.

add_variable:
        lda     #2
        sec                             ; Set carry to add 1 for length byte
        adc     decode_name_length      ; Add decode_name_length plus 1 (carry) to get total size to allocate
        pha                             ; Preserve length while we call grow
        ldy     #free_ptr               ; Grow variable name table by moving free_ptr up
        jsr     grow_a                  ; Do the grow
        pla                             ; Length back into A before w check error return
        bcs     @error
        ldy     #0                      ; Start writing length to name_ptr starting at offset 0
        sta     (name_ptr),y
        iny
        jsr     rebase_name_ptr         ; Add Y to name_ptr
        ldy     #0                      ; Start copying name at offset 0
@copy_next_character:
        lda     (decode_name_ptr),y     ; Get name character
        sta     (name_ptr),y            ; Store into name table
        bmi     @copy_last
        iny
        bne     @copy_next_character
@copy_last:
        iny                             ; Last character
        jsr     rebase_name_ptr         ; Make name_ptr point past end of data
        ldx     decode_name_type        ; Set up to clear the data bytes
        ldy     type_size_table,x
        iny                             ; Clear one more byte to recreate the 0 that terminates the name table
        ldax    name_ptr
        jsr     clear_memory            ; Clear the variable data
@done:
        clc                             ; Signal success
@error:
        rts
