
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

; Finds a name entry by its index.
; AX = pointer to the first entry in the name table
; Y = the index of the entry to find
; On success, return carry clear, and name_ptr points to the name table entry.
; If the function reaches the end of the name table, return carry set, and name_ptr will point to the last 0.

get_name:
        stax    next_name_ptr           ; This will be copied into name_ptr
        sty     name_index              ; Track the index in name_index
@next:
        jsr     advance_name_ptr        ; Advance to the next entry
        bcs     @done                   ; Reached end of table
        dec     name_index
        bpl     @next                   ; If index >= 0 then continue (this limits name table to 128 entries)
@done:
        rts                             ; Will return with carry clear on success

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
        ldx     #0                      ; X is the high byte of the length of the name table entry
        sec                             ; Set carry for error return if we find no more entries
        lda     (name_ptr),y            ; Load first byte of name table entry; may be single byte or high byte
        beq     advance_rebase_name_ptr_done    ; If length is zero then no more names
        bpl     @single_byte            ; High bit is clear; use this as the low byte
        and     #$7F                    ; Clear the high bit
        tax                             ; The byte we read is the high byte
        iny
        lda     (name_ptr),y            ; It was a two-byte length, so get the low byte at Y=1
@single_byte:
        clc
        adc     next_name_ptr           ; Add length to next_name_ptr
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
        ldy     #0                      ; Reset Y
        clc                             ; Not sure if carry is set or not so clear it now
        adc     name_ptr                ; Add to name_ptr
        sta     name_ptr
        bcc     advance_rebase_name_ptr_done
        inc     name_ptr+1
        clc                             ; Clear carry for return
advance_rebase_name_ptr_done:
        rts

; Extends the variable name table by adding a new name.
; The new name consists of the characters defined by decode_name_ptr and decode_name_length.
; These are both set in decode_name. The name must already end in a character with the high bit set.
; The type in decode_name_type determines the size of the variable.
; name_ptr = a pointer to the 0 at the end of the variable name table (left by find_name)
; Returns carry clear on success or carry set on failure.
; On return, updates name_ptr to point to the data following the new name, as if found by find_name.

add_variable:
        ldx     decode_name_type        ; Figure out the variable size based on the type
        lda     type_size_table,x
        sec                             ; Set carry to add 1 for length byte
        adc     decode_name_length      ; Add decode_name_length plus 1 (carry) to get total size to allocate
        pha                             ; Preserve length while we call grow
        ldy     #array_name_table_ptr   ; Grow variable name table by moving array_name_table_ptr up
        jsr     grow_a                  ; Do the grow
        pla                             ; Length back into A
        ldy     #0                      ; Start writing length to name_ptr starting at offset 0
        sta     (name_ptr),y
        iny
        jsr     copy_name
        ldx     decode_name_type        ; Set up to clear the data bytes
        ldy     type_size_table,x
        iny                             ; Clear one more byte to recreate the 0 that terminates the name table
        ldax    name_ptr
        jmp     clear_memory            ; Clear the variable data

; Finds a variable, or adds it.
; decode_name_ptr = pointer to the variable name
; decode_name_length = the length of the variable

find_or_add_variable:
        lda     decode_name_arity       ; Is it an array?
        bmi     @array                  ; Go handle array
        ldax    variable_name_table_ptr
        jsr     find_name               ; Look for a variable with this name
        bcs     add_variable            ; Most common case is that it's found, so branch only if it's not
        rts

@array:
        jsr     evaluate_argument_list  ; Evaluate the array arguments: arity $FF is still in A
        inc     line_pos                ; Skip ')'
        eor     #$FF                    ; A is now arity of array reference
        sta     decode_name_arity
        ldax    array_name_table_ptr
        jsr     find_name               ; Look for an array with this name
        bcc     find_array_element
        mva     decode_name_arity, D    ; Do DIM var(10, 10, ..., 10); D counts down arity
        lday    #fp_ten
        jsr     load_fp0                ; Set FP0 to 10
@push:
        jsr     push_fp0
        dec     D
        bne     @push                   ; Push one more
        jsr     dimension_array         ; Returns with name_ptr set to array data

; Fall through

; Moves name_ptr, which is assumed to pointing to the byte after the end of an array name in the array table,
; to an element offset based on the indexes that are on the expression stack.

find_array_element:
        ldy     #0                      ; Arity is at offset 0
        sty     array_element_offset    ; Array element offset starts at 0
        sty     array_element_offset+1
        sty     array_element_size+1    ; High byte of array element size starts at 0
        lda     (name_ptr),y            ; Get arity
        cmp     decode_name_arity       ; Check if the arity of this reference matches the array
        raine   ERR_ARITY_MISMATCH      ; Arity doesn't match so return error
        sta     D                       ; Use D to count down arity
        iny
        jsr     rebase_name_ptr         ; Advance name_ptr past arity
        ldx     decode_name_type        ; Figure out the element size from type: start of multiplication process
        lda     type_size_table,x       ; Initialize array_element_size to the size of one value of the array's type
        sta     array_element_size
@next:
        jsr     pop_int_fp0             ; Get the next value off the stack
        jsr     imul_16                 ; Multiply it by the value in array_element_size
        sta     E                       ; Park low byte in E
        ldy     #0                      ; Read next dimension value starting at name_ptr
        lda     (name_ptr),y            ; Copy low and high byte of limit into array_element_size
        sta     array_element_size
        iny
        lda     (name_ptr),y
        sta     array_element_size+1
        iny
        jsr     rebase_name_ptr         ; Move name_ptr to the next dimension value
        txa                             ; Compare the multiplication result (currently in EX) with the limit
        cmp     array_element_size+1    ; Result high byte < limit high byte?
        bcc     @ok                     ; <
        bne     name_out_of_range            ; >, otherwise =
        lda     E                       ; Same with low byte
        cmp     array_element_size
        bcs     name_out_of_range            ; >=
@ok:
        lda     E                       ; Result still in EX; make sure we have low byte of result in A
        adc     array_element_offset    ; Add result to array_element_offset; carry will always be clear
        sta     array_element_offset
        txa
        adc     array_element_offset+1
        sta     array_element_offset+1
        dec     D
        bne     @next                   ; Carry should be clear here because array offset calculation must not overflow
        clc
        lda     name_ptr                ; Add array_element_offset to name_ptr
        adc     array_element_offset
        sta     name_ptr
        lda     name_ptr+1
        adc     array_element_offset+1
        sta     name_ptr+1
        rts

name_out_of_range:
        raise   ERR_OUT_OF_RANGE

ARRAY_TRIAL_GROW_SIZE = $80

; Adds a new array variable.
; The requirements of add_variable apply: name_ptr must be at the end of the name table etc.
; The number of dimensions is in decode_name_arity. The dimensions are on the value stack.
; Returns carry clear on success or carry set on error.

dimension_array:

; First, do a trial allocation of ARRAY_TRIAL_GROW_SIZE bytes to make sure we have enough space to store the
; dimensions. If it works then shrink back.

        lda     #ARRAY_TRIAL_GROW_SIZE
        ldy     #free_ptr
        jsr     grow_a
        lda     #ARRAY_TRIAL_GROW_SIZE  ; Cheaper in terms of space to shrink, rather than save/restore free_ptr
        ldy     #free_ptr
        jsr     shrink_a

; Set up the first few fields.

        mvax    name_ptr, dst_ptr       ; Remember name_ptr in dst_ptr so we can update the length later
        ldy     #2                      ; We don't know the length yet so just skip over it
        jsr     copy_name               ; name_ptr now points past end of name; resets Y to 0
        lda     decode_name_arity       ; Copy arity into name table
        sta     (name_ptr),y            ; This will be the byte after the name
        sta     D                       ; D = arity countdown
        iny                             ; Will start writing the dimension values from here

; Calculate space required for this array:
; 2 bytes for name table entry length
; decode_name_length bytes for name
; 1 byte for arity
; 2 * decode_name_arity bytes for dimension values
; element size * D1 * D2 * ... * Dn bytes for data

        ldx     decode_name_type        ; Figure out the element size from type: start of multiplication process
        lda     type_size_table,x
        ldx     #0                      ; AX is the 16-bit size
        stax    array_element_size
@next:
        sty     E                       ; Preserve current write position relative to name_ptr in E
        jsr     pop_int_fp0             ; Get the next value off the stack (preserves DE)
        clc
        adc     #1                      ; Add one because DIM(n) creates n+1 elements from 0 to n
        bcc     @skip_inx
        inx
@skip_inx:
        jsr     imul_16                 ; Multiply the current element size by the new value
        bcs     name_out_of_range            ; Size >= 64K
        bmi     name_out_of_range            ; Size >= 32K
        stax    array_element_size
        ldy     E                       ; Write position
        sta     (name_ptr),y            ; The value we're writing is the size of the array so far
        txa
        iny
        sta     (name_ptr),y
        iny
        dec     D                       ; One down
        bne     @next                   ; More to go

; At this point, Y is coincidentally equal to 1 + arity * 2.
; name_ptr still points to the first byte after the name, which is where we'll leave it.
; name_ptr + Y is the start of the array element data.

        tya                             ; Calculate start of array data and store in BC
        clc
        adc     name_ptr
        ldx     name_ptr+1
        bcc     @skip_inx_2
        inx
@skip_inx_2:
        stax    BC
        tya                             ; Again start with Y and calculate total size of name table entry
        clc
        adc     #2                      ; Add 2 for length bytes at start of name table entry; assume no overflow
        adc     decode_name_length      ; Name length; assume no overflow
        adc     array_element_size      ; Add in the space required for the data elements; assume no overflow
        sta     size                    ; Save in size
        lda     #0
        tay                             ; Will need 0 in Y too
        adc     array_element_size+1
        sta     size+1
        bmi     name_out_of_range            ; It can't be >= 64K but might be >= 32K
        ora     #$80                    ; High bit was clear before; now it's set
        sta     (dst_ptr),y             ; Store high byte of length with high bit set
        iny
        lda     size
        sta     (dst_ptr),y             ; Low byte
        ldax    size
        ldy     #free_ptr
        jsr     grow                    ; Grow to accommodate the entire array; clobbers size and DE
        mvax    BC, dst_ptr             ; Prepare to clear array data from address stored in BC
        ldy     #0                      ; Initialize Y to 0
        tya                             ; Set with 0
@next_block:
        dec     array_element_size+1    ; Will only go negative if it was 0 to start; size can't be >=32K
        bmi     @no_more_blocks         ; No more blocks
        jsr     set_memory
        inc     dst_ptr+1               ; Move pointer to next block
        bne     @next_block             ; Unconditional since dst_ptr should not roll over
@no_more_blocks:
        ldy     array_element_size      ; Set the remaining bytes
        iny                             ; Increment so we also set 0 at the end of the name table
        jsr     set_memory
@no_remaining_bytes:
        rts

; Copies the decoded name into the name table, ending at a character with the EOT bit set.
; decode_name_ptr = copy source
; name_ptr = destination
; Y = Offset to add to name_ptr prior to start of copy (avoids inevitably having to do this in calling function)
; Returns with name_ptr pointing to the byte after the name.

copy_name:
        jsr     rebase_name_ptr         ; Add Y to name_ptr; resets Y to 0
@copy_next_character:
        lda     (decode_name_ptr),y     ; Get name character
        sta     (name_ptr),y            ; Store into name table
        bmi     @copy_complete
        iny
        bne     @copy_next_character    ; Unconditional

@copy_complete:
        iny                             ; Last character
        jmp     rebase_name_ptr         ; Make name_ptr point past end of data

; Multiply the 16-bit operand in array_element_size with the 16-bit operand in AX. Returns the result in AX.
; Returns carry clear on success or carry set if the result overflowed.
; Y SAFE, BC SAFE, DE SAFE (but uses S0 and S1)

imul_16:
        stax    S1                      ; Hold operand in S1
        ldx     #16                     ; Number of shift operations
        mva     #0, S0                  ; Accumulate product in S0
        sta     S0+1
@next:
        asl     S0
        rol     S0+1
        bcs     @overflow               ; Product overflowed
        asl     S1
        rol     S1+1
        bcc     @skip_add
        clc
        lda     S0
        adc     array_element_size
        sta     S0
        lda     S0+1
        adc     array_element_size+1
        sta     S0+1
@skip_add:
        dex
        bne     @next
        ldax    S0
@overflow:
        rts
