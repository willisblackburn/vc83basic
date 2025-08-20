.include "macros.inc"
.include "basic.inc"

; Loads a string into one of the two S registers.
; Returns length in A and a pointer to the string data in the selected S register: either S0 for load_s0, or S1
; for load_s1.
; AY = a pointer to the string to load
; DE SAFE

load_s1:
        ldx     #S1
        bne     load_s        
load_s0:
        ldx     #S0
load_s:
        stay    BC                      ; BC is a temporary pointer
        sty     1,x                     ; Store high byte of string address
        tay                             ; Move low byte into Y since I'm about to clobber A
        ora     C                       ; Check for null
        beq     @null_string            ; A is conveniently 0 for return
        iny                             ; Increment low byte of address
        sty     0,x                     ; Store low byte of string address
        bne     @skip_inc               ; Low byte didn't roll over so don't have to adjust high byte
        ldy     C                       ; High byte is in C, so re-load and re-store
        iny
        sty     1,x
@skip_inc:
        ldy     #0                      ; Length offset
        lda     (BC),y                  ; Load the length for return
@null_string:
        rts

; Parses a string from read_ptr and writes it to a new string allocated from string space.
; Stops parsing upon reaching the termination character. If the first character of the input is a double quote, then
; the termination character is also a double quote, and read_string interprets two double-quotes in the middle of the
; string as a single quote. Otherwise the termination character is a comma (',').
; Finding a NUL in the input terminates the string no matter what.
; AX = the buffer address (stored in read_ptr)
; Y = the starting offset
; Leaves string_ptr pointing at the string and the last read position in Y, carry clear if ok, carry set if error.

read_string:
        stax    read_ptr                ; Store read_ptr
        jsr     find_printable_character    ; Skip any whitespace        
        sty     B                       ; Read position relative to read_ptr
        ldax    #(255 + STRING_EXTRA + STRING_EXTRA)    ; Allocate space for 2 strings with total length of 255
        jsr     string_alloc_memory
        bcs     @done
        ldy     B
        lda     (read_ptr),y            ; Get first character
        iny                             ; Skip past it in case it's a double quote
        cmp     #'"'                    ; Is first character a double quote?
        beq     @store_terminator       ; It is, use it
        lda     #','                    ; No; terminator is a comma
        dey                             ; Move back so we read it again
@store_terminator:
        sta     D                       ; Store terminator in D
        sty     B                       ; Update read offset in B
        lda     #1
        sta     C                       ; Initialize write position relative to string_ptr
@next:
        ldy     B                       ; Read offset
        lda     (read_ptr),y            ; Get next source character
        beq     @finish                 ; Was zero, definitely finished
        cmp     D                       ; Was it the terminator?
        bne     @not_terminator         ; Nope
        cmp     #'"'                    ; Was the terminator also double quote?
        bne     @finish                 ; Nope; we're finished
        inc     B                       ; Always skip over this quote
        iny                             ; Increment Y in order to check the next character
        cmp     (read_ptr),y            ; Check second double quote (if present cannot have EOT set)
        bne     @finish                 ; Nope, just finish; B points to character after double quote
@not_terminator:
        ldy     C                       ; Write offset
        sta     (string_ptr),y          ; Store in output
        inc     B                       ; Increment read and write offset
        inc     C
        jmp     @next

; When we get here, B always points to the next read position, and the length of the string is in C.

@finish:
        ldy     #0                      ; Offset 0 relative to string_ptr is the length of the string we just read
        ldx     C                       ; Length of the string (plus one for length byte)
        dex                             ; Remove length byte
        txa
        sta     (string_ptr),y          ; Store length
        clc                             ; Add length to string_ptr to get address of second string less STRING_EXTRA
        adc     string_ptr
        sta     D                       ; Store that pointer in DE
        lda     string_ptr+1
        adc     #0
        sta     E
        ldy     #STRING_EXTRA           ; Add STRING_EXTRA via Y
        txa                             ; Length
        eor     #$FF                    ; Invert bits to produce 255 - length
        sta     (DE),y                  ; Store it
        ldy     B                       ; Return read position in Y
@done:
        rts                             ; If we reached here via @finish, carry guaranteed to be clear by ADC

; Allocates a new string on the string heap.
; A = the length of the new string (not including length byte)
; Returns the address of the new string in string_ptr and in AY (to make it easy to pass to load_s0/s1).
; BC SAFE (if compact not called), DE SAFE

string_alloc:
        pha                             ; Remember the requested size in order to set it into string later
        ldx     #0                      ; Initialize high byte of block length to 0
        clc
        adc     #STRING_EXTRA           ; Add 3 bytes to length: 1 byte for length, 2 bytes for GC relocation pointer
        bcc     @skip_inx               ; If no carry then leave high byte at 0
        inx                             ; Otherwise it's 1
@skip_inx:
        jsr     string_alloc_memory     ; Allocate memory
        pla                             ; Get size we saved earlier
        bcs     @error                  ; Allocation failed
        ldy     #0
        sta     (string_ptr),y          ; Set the length of the allocated string
@error:
        lday    string_ptr              ; Return pointer in AY
        rts

; Allocates memory for a new string on the string heap. Called from string_alloc with the total amount of memory
; needed for the string, which is the string length plus STRING_EXTRA bytes of overhead.
; AX = the memory required for the new string
; BC SAFE (if compact not called), DE SAFE

string_alloc_memory:
        stax    line_number             ; Borrow line_number to save requested size in case we have to retry
        jsr     @try
        bcc     @success

@insufficient_memory:
        jsr     compact                 ; Try to compact the string heap
        ldax    line_number             ; Recover size for retry
@try:
        eor     #$FF                    ; Invert length and set carry in order to do string_ptr - AX
        sec                             ; This calculates proposed new value for string_ptr
        adc     string_ptr
        tay                             ; Store low byte of proposed value in Y
        txa                             ; Do the same thing with the high byte
        eor     #$FF
        adc     string_ptr+1
        tax                             ; Store high byte of proposed value in X
        cpx     free_ptr+1              ; Compare high byte vs. free_ptr
        bcc     @error                  ; New string_ptr high byte < free_ptr; it's definitely an error
        bne     @string_ptr_ok          ; If it's greater then it's definitely okay
        cpy     free_ptr
        bcc     @error                  ; Less than free_ptr is an error, but >= is okay
@string_ptr_ok:
        sty     string_ptr              ; Proposed string_ptr >= free_ptr; go update it
        stx     string_ptr+1
        clc                             ; Signal success
        rts

@error:
        sec                             ; Because math @error is reached from BCC so have to set carry
@success:
        rts

; Compacts the string space.
; Moves all strings that are still referenced by variables (or from the value stack) to their highest possible
; address. The algorithm uses two bytes after the end of each string to store its relocation offset relative to
; the start of the string space (string_ptr). The string_alloc function allocates 3 (STACK_EXTRA) extra bytes to
; accommodate the length of the string and the two-byte relocation offset.
; DE SAFE

; Logic depends on being able to add string length + 3 to get to next string.
.assert STRING_EXTRA = 3, error

compact:

; Phase 1: Set the relocation offset high byte of all strings to $FF.

        ldax    #phase_1_clear_string
        jsr     for_all_strings

; Phase 2: Find all string variables and mark each string in memory.

        ldax    #phase_2_mark_string
        jsr     for_all_referenced_strings

; Phase 3: Calculate the relocation offset for each string and determine total size of string space.

        mva     #0, size                ; Set size to 0
        sta     size+1
        ldax    #phase_3_calculate_relocation_offset
        jsr     for_all_strings

; Phase 4: Update string variables to point to the new addresses.
; After calculating relocation offsets, size is now the total size of all strings, and the new value of string_ptr
; is himem_ptr minus that size. Store new string_ptr value in BC.

        sec                             ; Subtract size from himem_ptr to get the new string_ptr value
        lda     himem_ptr
        sbc     size
        sta     B                       ; Store in BC
        lda     himem_ptr+1
        sbc     size+1
        sta     C
        ldax    #phase_4_update_string
        jsr     for_all_referenced_strings

; Phase 5: Move each still-referenced string down to free_ptr + its relocation offset.
; For each string we take one of two paths. If it's marked, we call copy to move its length byte and data, which
; will leave src_ptr pointing to its relocation offset. If it's not marked, we just add the length plus one to
; src_ptr, which also leaves src_ptr pointing to the relocation offset. We don't need to actually copy the
; relocation offset itself, as it's not needed after this phase.

        ldax    #phase_5_relocate_string
        jsr     for_all_strings

; Phase 6: All the strings have been relocated to free_ptr.
; The new value of string_ptr is in BC. Subtract it from himem_ptr to get the size to copy.

        sec                             ; Do himem_ptr - BC and store in size
        lda     himem_ptr
        sbc     B
        pha                             ; Save for call to copy
        lda     himem_ptr+1
        sbc     C
        pha
        mvax    BC, string_ptr          ; Set up new string_ptr
        stax    dst_ptr                 ; Also destination for copy
        mvax    free_ptr, src_ptr
        plax                            ; Get the size we pushed earlier
        jsr     copy
        rts                             ; All done!

; Invokes a handler each string in the string heap.

for_all_strings:
        stax    vector_table_ptr        ; Use vector_table_ptr to store the handler vector
        mvax    string_ptr, src_ptr
        bne     @next                   ; Unconditional since high byte of string_ptr can't be zero

@continue:
        jsr     handle_string
        lda     #STRING_EXTRA - 2       ; Move to next string; minus 2 because two calls to "plus_one" function
        jsr     add_src_ptr_plus_one
@next:
        jsr     check_src_ptr
        bcc     @continue
        rts

; Invokes a handler vector for each string value in the variable name table.

for_all_referenced_strings:
        stax    vector_table_ptr        ; Use vector_table_ptr to store the handler vector
        ldax    variable_name_table_ptr ; Prepare to scan variables
        jsr     initialize_name_ptr
        bne     @next                   ; Unconditional since initialize_name_ptr exits with Z clear

@continue:
        jsr     set_name_ptr_data
        beq     @next                   ; Not a string; move on to the next one
        jsr     load_src_ptr_handle_string
@next:
        jsr     advance_name_ptr
        bcc     @continue
        ldax    array_name_table_ptr    ; Prepare to scan arrays
        jsr     initialize_name_ptr
        bne     @next_array

; And each string value in the array name table.

@continue_array:
        jsr     set_name_ptr_data       ; Sets name_ptr to first byte after the name, which will be the arity
        beq     @next_array             ; Not a string array; move on to the next one
        ldy     #0
        lda     (name_ptr),y            ; Load arity
        asl     A                       ; Arity *2 because we need to skip past 16-bit multiplier for each dimension
        tay                             ; Into Y
        iny                             ; Increment so we also skip past the arity itself
@next_element:
        jsr     rebase_name_ptr         ; Move name_ptr so it now points to the next array element
        lda     name_ptr+1              ; Check if we've run out of array elements
        cmp     next_name_ptr+1
        bne     @continue_element       ; Not yet
        lda     name_ptr                ; Maybe; check low byte too
        cmp     next_name_ptr
        beq     @next_array             ; Out of array elements
@continue_element:
        jsr     load_src_ptr_handle_string
        ldy     #2
        bne     @next_element           ; Unconditional because Y=2

@next_array:
        jsr     advance_name_ptr
        bcc     @continue_array

; And each string variable on the expression stack.
; In this section we use name_ptr to point to the value on the stack, just as in the variable and array sections.

        ldpha   stack_pos               ; Save stack_pos value

@continue_stack_value:
        cmp     #PRIMARY_STACK_SIZE     ; Stack empty?
        beq     @stack_done
        tax
        lda     stack+Value::type,x     ; Get value type
        bmi     @stack_done             ; If it's negative then it's a control structure: no more values
        beq     @next_stack_value       ; Not a string
        stx     name_ptr                ; Set up name_ptr to point into stack
        mva     #>stack, name_ptr+1
        jsr     load_src_ptr_handle_string

@next_stack_value:
        jsr     stack_free_value
        bne     @continue_stack_value   ; Unconditional: freeing value will never leave stack_pos = 0

@stack_done:
        plsta   stack_pos               ; Restore stack_pos
        rts

; Loads src_ptr from name_ptr and then falls through to handle_string.

load_src_ptr_handle_string:
        ldy     #0
        lda     (name_ptr),y            ; Set up src_ptr
        sta     src_ptr
        iny
        lda     (name_ptr),y
        sta     src_ptr+1

; Fall through

; With src_ptr pointing to a string, adds the length of the string referenced by src_ptr plus one to src_ptr, so that
; src_ptr points to the relocation offset.
; When calling the handler, X will contain the length of the string.

handle_string:
        lda     src_ptr                 ; Check if src_ptr is null
        ora     src_ptr+1
        beq     @done                   ; It is
        ldy     #0
        lda     (src_ptr),y             ; Load length first
        tax                             ; Move into X in case someone wants it later
        jsr     add_src_ptr_plus_one
        jmp     (vector_table_ptr)      ; Jump to handler; RTS from handler will return to point after JSR @invoke

@done:
        rts

; Phase 1 handler

phase_1_clear_string:
        iny
        lda     #$FF
        sta     (src_ptr),y             ; Set relocation offset high byte to $FF
        rts

; Phase 2 handler

phase_2_mark_string:
        iny
        lda     #0
        sta     (src_ptr),y             ; Set relocation offset high byte to 0
        rts

; Phase 3 handler

phase_3_calculate_relocation_offset:
        lda     size                    ; Save current value of size into relocation offset
        sta     (src_ptr),y
        iny
        lda     (src_ptr),y             ; Marked?
        bne     @unmarked               ; Unmarked strings will have a non-zero address high byte
        lda     size+1
        sta     (src_ptr),y
        txa                             ; Length is in X from handle_string
        jsr     add_size                ; Add to size
        lda     #STRING_EXTRA
        jmp     add_size                ; Allow for string overhead

@unmarked:
        rts

; Phase 4 handler

phase_4_update_string:
        clc                             ; Do new string_ptr (BC) + relocation offset into variable address
        lda     (src_ptr),y
        adc     B
        sta     (name_ptr),y
        iny                             ; Y=1
        lda     (src_ptr),y
        adc     C
        sta     (name_ptr),y
        rts

; Phase 5 handler

phase_5_relocate_string:
        clc                             ; Add free_ptr to relocation offset to get the copy destination
        lda     (src_ptr),y
        adc     free_ptr
        sta     dst_ptr                 ; Save into dst_ptr
        iny
        lda     (src_ptr),y
        adc     free_ptr+1              ; Have to do the math first since CMP will clobber carry
        sta     dst_ptr+1
        lda     (src_ptr),y             ; Reload the high byte
        cmp     #$FF                    ; Check if it's $FF meaning it was not marked
        beq     @unmarked               ; Yep, skip the copy and move on

; src_ptr now points to the relocation offset, so subtract the length (still in X) and 1 (length byte) to recover
; the original value:
;     src_ptr = src_ptr - X - 1
; We can't subtract X, though, so we need to express this as an operation starting with X:
;     src_ptr = -X - 1 + src_ptr
; EOR of X with $FF generates -X - 1, so just add src_ptr to that. Decrement the high byte if carry set.

        txa
        eor     #$FF
        clc
        adc     src_ptr                 ; Conceptually this is: SEC, LDA src_ptr, SBC X, if carry clear DEC high byte
        sta     src_ptr
        bcs     @skip_dec
        dec     src_ptr+1
@skip_dec:
        inx                             ; Length is still in X; add 1 to account for length byte
        txa                             ; Size low byte into A
        beq     @x_is_zero
        ldx     #$FF                    ; Set X to -1 so when we INX it will be 0
@x_is_zero:
        inx                             ; X must now be 0 or 1
        jmp     copy                    ; Copy from src_ptr to dst_ptr

@unmarked:
        rts

; Rebases name_ptr so it points to the variable data.
; Returns the type of variable in A.

.assert TYPE_NUMBER = $00, error
.assert TYPE_STRING = $01, error

set_name_ptr_data:
        ldy     #$FF                    ; Scan forward to find the end of the name
@next:
        iny
        lda     (name_ptr),y
        bpl     @next
        ldx     #TYPE_NUMBER
        cmp     #'$' | EOT              ; Was it a string?
        bne     @not_string
        inx                             ; It was a string; change the type
@not_string:
        iny                             ; Advance past last character
        jsr     rebase_name_ptr         ; Point name_ptr to data
        txa                             ; Return type in A (setting flags)
        rts

; Checks if src_ptr is < himem_ptr.
; Returns carry clear if it is, otherwise carry set.

check_src_ptr:
        lda     src_ptr+1               ; Is src_ptr < himem_ptr?
        cmp     himem_ptr+1
        bcc     @done                   ; High byte is less; exit with carry clear
        bne     @done                   ; If greater than exit with carry set
        lda     src_ptr                 ; Compare low byte
        cmp     himem_ptr
@done:
        rts

; Adds the value in A plus one to src_ptr. Always adds one more than A to make make skipping over the length byte
; and string data easier.

add_src_ptr_plus_one:
        sec                             ; The "plus one" part
        adc     src_ptr
        sta     src_ptr
        bcc     @done                   ; Carry was clear so don't need to increment high byte
        inc     src_ptr+1
@done:
        rts

; Adds the value in A to size.

add_size:
        clc
        adc     size
        sta     size
        bcc     @done
        inc     size+1
@done:
        rts
