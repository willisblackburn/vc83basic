.include "macros.inc"
.include "basic.inc"

; Matches the input against names from a table.
; Each name table node consists of a length (one byte if in the range 0-127, otherwise two bytes, high byte first),
; followed by a name, followed by any number of extra data bytes. The last byte of the name must have bit 7 set.
; AX = pointer to the first node in the name table; saved into next_node_ptr
; name_ptr = pointer to the name to match
; Returns carry clear if the name matched and carry set if it didn't match any name.
; On match, updates node_ptr to point to the data following matched name, and returns the index of the matched name
; in A.
; If no match, then A is the number of names in the name table and node_ptr points to the 0 at the end of the table.

find_name:
        jsr     initialize_node_ptr
find_name_2:
        inc     matched_name_index      ; Increment name index
        jsr     advance_node_ptr        ; Tee up next node
        bcs     @done
        jsr     match_name              ; Try to match
        bcs     find_name_2             ; If no match then try next one
        jsr     rebase_node_ptr         ; Advance node_ptr to point to data after name
@done:
        lda     matched_name_index      ; Matched index or number of entries in the name table
        rts

; Matches a name found in the input buffer with characters from the name table node.
; name_ptr = pointer to the name to match
; node_ptr = pointer to the name within the name table node that we're going to match
; Returns carry clear if the sequence matched. Y will be left set to the length of the matched name.
; Returns carry set if no match.
; BC SAFE, DE SAFE

match_name:
        ldy     #0                      ; Start matching at position 0; also clears N flag
@next:
        lda     (node_ptr),y            ; Load next byte from name table node
        bmi     @last                   ; This is the last character
        cmp     (name_ptr),y            ; Compare to the source name
        bne     @no_match               ; If not match then fail; if we get past this point then we're still matching
        iny
        bne     @next

@last:
        cmp     (name_ptr),y            ; One last compare
        bne     @no_match
        iny                             ; Account for matching last character
        clc                             ; Signal success
        rts
        
@no_match:
        sec                             ; Signal error
        rts

; Saves a new value (passed in AX) into node_ptr and also resets matched_name_index to 0.
; AX = pointer to the start of the name table

initialize_node_ptr:
        stax    next_node_ptr           ; This will be copied into node_ptr
        mva     #$FF, matched_name_index    ; Initialize name table index to -1 so first INC makes it 0
        rts

; Replaces node_ptr with next_node_ptr and advances next_node_ptr.
; next_node_ptr = a pointer to the current name table node (updated)
; Returns carry clear if node_ptr points to a valid node, or set if it is pointing to the end of the name table.
; BC SAFE, DE SAFE

advance_node_ptr:
        mvax    next_node_ptr, node_ptr ; Advance to next node
        ldy     #0                      ; node_ptr index
        ldx     #0                      ; X is the first byte of the name table node
        sec                             ; Set carry for error return if we find no more nodes
        lda     (node_ptr),y            ; Load first byte of name table node; may be single byte or high byte
        beq     advance_rebase_node_ptr_done    ; If length is zero then no more names
        bpl     @single_byte            ; High bit is clear; just add this as the low byte
        and     #$7F                    ; Clear the high bit
        tax                             ; The byte we read is the high byte
        iny
        lda     (node_ptr),y            ; It was a two-byte length, so get the low byte at Y=1
@single_byte:
        clc
        adc     next_node_ptr           ; Add AX to next_node_ptr
        sta     next_node_ptr
        txa
        adc     next_node_ptr+1
        sta     next_node_ptr+1
        iny                             ; Y is now the number of bytes in the length

; Fall through

; Rebases node_ptr by adding Y.
; node_ptr = pointer to somewhere within the current name table node
; Y = the offset to add to node_ptr
; Always succeeds. Returns with carry clear, node_ptr updated.
; X SAFE, Y SAFE, BC SAFE, DE SAFE

rebase_node_ptr:
        tya                             ; Move offset into A and add to node_ptr
        clc                             ; Not sure if carry is set or not so clear it now
        adc     node_ptr                ; Add to node_ptr
        sta     node_ptr
        bcc     advance_rebase_node_ptr_done
        inc     node_ptr+1
        clc                             ; Clear carry for return
advance_rebase_node_ptr_done:
        rts

; Finds a variable, or adds it.
; name_ptr = pointer to the variable name
; name_length = the length of the variable
; Returns carry clear if find_name or add_variable succeeded, or carry set on error.

find_or_add_variable:
        ldax    variable_name_table_ptr
        jsr     find_name               ; Look for a variable with this name
        bcs     @not_found              ; Most common case is that it's found, so branch only if it's not
        rts                             ; Return success

@not_found:
        ldax    #2                      ; Allocate 2 bytes of space for the variable

; Fall through

; Extends the variable name table by adding a new name.
; The new name consists of the characters defined by name_ptr and name_length. These are both set in decode_name.
; The name must already end in a character with the high bit set.
; AX = the number of data bytes to allocate after the name
; node_ptr = a pointer to the 0 at the end of the variable name table (left by find_name)
; matched_name_index = the number of names currently in the table (also left by find_name)
; Returns carry clear on success or carry set on failure.
; On return, updates node_ptr to point to the data following the new name, as if found by find_name.
add_variable:
        sec                             ; Set carry in case the variable count check fails and to add 1 for length
        ldy     matched_name_index      ; Check if too many variables already
        bmi     @error                  ; variable_count >= 128
        adc     name_length             ; Add name_length plus 1 (carry) to get total size to allocate
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
        mvax    node_ptr, dst_ptr       ; Prepare to clear the newly-allocated node
        ldax    BC                      ; Recover size
        jsr     clear_memory
        sta     (dst_ptr),y             ; Y will be first uncleared byte on return; clear it to terminate name table
        ldy     #0                      ; Start writing length to node_ptr starting at offset 0
        ldx     C                       ; Consider the high byte
        bne     @write_two_byte_length  ; High byte is non-zero; use two-byte encoding
        lda     B                       ; Consider the low byte again (note we are discarding the zero high byte)
        bpl     @write_length_low_byte  ; It's < 128; just use single-byte encoding
@write_two_byte_length:
        txa                             ; High byte into A
        eor     #$80                    ; Set high bit, which we know is clear because we tested it before
        sta     (node_ptr),y
        iny
        lda     B                       ; Replace A with low byte
@write_length_low_byte:
        sta     (node_ptr),y
        iny
        jsr     rebase_node_ptr         ; Add Y to node_ptr
        ldy     #0                      ; Start copying name at offset 0
@copy_next_character:
        lda     (name_ptr),y            ; Get name character
        sta     (node_ptr),y            ; Store into name table
        bmi     @copy_last
        iny
        bne     @copy_next_character

@copy_last:
        iny                             ; Last character
        jsr     rebase_node_ptr         ; Make node_ptr point past end of data
        clc                             ; Signal success
        rts

@error:
        sec                             ; Signal error
        rts
