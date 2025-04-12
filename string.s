.include "macros.inc"
.include "basic.inc"

; Loads a string into one of the two S registers.
; Returns length in A and a pointer to the string data in the selected S register: either S0 for load_s0, or S1
; for load_s1.
; AY = a pointer to the string to load
; BC SAFE

load_s1:
        ldx     #S1
        bne     load_s        
load_s0:
        ldx     #S0
load_s:
        stay    DE                      ; DE is a temporary pointer
        sty     1,x                     ; Store high byte of string address
        tay                             ; Move low byte into Y since I'm about to clobber A
        ora     E                       ; Check for null
        beq     @null_string            ; A is conveniently 0 for return
        iny                             ; Increment low byte of address
        sty     0,x                     ; Store low byte of string address
        bne     @skip_inc               ; Low byte didn't roll over so don't have to adjust high byte
        ldy     E                       ; High byte is in E, so re-load and re-store
        iny
        sty     1,x
@skip_inc:
        ldy     #0                      ; Length offset
        lda     (DE),y                  ; Load the length for return
@null_string:
        rts

; Parses a string from src_ptr and writes it to a new string allocated from string space.
; Stops parsing upon reaching the termination character. If the first character of the input is a double quote, then
; the termination character is also a double quote, and read_string interprets two double-quotes in the middle of the
; string as a single quote. Otherwise the termination character is a comma (',').
; Finding a NUL in the input terminates the string no matter what.
; AX = the buffer address (stored in src_ptr)
; Y = the starting offset
; Returns the address of the new string in AX and the last read position in Y, carry clear if ok, carry set if error.

read_string:
        stax    src_ptr                 ; Store src_ptr
        sty     B                       ; Read position relative to src_ptr
        lda     #0                      ; Allocate 0-byte string
        jsr     string_alloc            ; Don't care about the address of this string
        bcs     @done
        lda     #255                    ; Allocate second 255-byte string
        jsr     string_alloc
        bcs     @done
        ldy     B
        lda     (src_ptr),y             ; Get first character
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
        lda     (src_ptr),y             ; Get next source character
        and     #$7F                    ; Remove EOT bit if set
        beq     @finish                 ; Was zero, definitely finished
        cmp     D                       ; Was it the terminator?
        bne     @not_terminator         ; Nope
        cmp     #'"'                    ; Was the terminator also double quote?
        bne     @finish                 ; Nope; we're finished
        inc     B                       ; Always skip over this quote
        iny                             ; Increment Y in order to check the next character
        cmp     (src_ptr),y             ; Check second double quote (if present cannot have EOT set)
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
        ldax    string_ptr              ; Return pointer to string in AX
        ldy     B                       ; Return read position in Y
@done:
        rts                             ; If we reached here via @finish, carry guaranteed to be clear by ADC

; Allocates space for a new string on the string heap.
; A = the length of the new string (not including length byte)
; Returns the address of the new string in AX.
; BC SAFE

string_alloc:
        pha                             ; Push the requested size in case we have to retry
        jsr     @try_string_alloc
        bcc     @success                ; If it worked then great, return
        jsr     compact                 ; Try to compact the string heap
        pla                             ; Recover size for retry
        jsr     @try_string_alloc
        bcc     @success_2
@error:
        sec                             ; Sometimes @error is reached from BCC so have to set carry
        rts

@success:
        pla                             ; Drop the length we saved on the stack
@success_2:
        ldax    string_ptr              ; Return pointer in AX
        rts

@try_string_alloc:
        sta     size                    ; Store length in size for updating length byte later
        ldx     #0                      ; Initialize high byte of block length to 0
        clc
        adc     #STRING_EXTRA           ; Add 3 bytes to length: 1 byte for length, 2 bytes for GC relocation pointer
        bcc     @skip_inx               ; If no carry then leave high byte at 0
        inx                             ; Otherwise it's 1
@skip_inx:
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
        lda     size                    ; Recover size
        ldy     #0                      ; Offset of length        
        sta     (string_ptr),y          ; Set the length of the allocated string
        clc                             ; Signal success
        rts

; Compacts the string space.
; Moves all strings that are still referenced by variables (or from the value stack) to their highest possible
; address. The algorithm uses two bytes after the end of each string to store its relocation address. The
; string_alloc function allocates 3 (STACK_EXTRA) extra bytes to accommodate the length of the string and the two-byte
; relocation address.
; BC SAFE

; Logic depends on being able to add string length + 3 to get to next string.
.assert STRING_EXTRA = 3, error

compact:

; Phase 1: Set the relocation address low byte of all strings to 0.

        mvax    string_ptr, src_ptr     ; Use src_ptr to scan string space
        bne     @clear_next_2           ; Unconditional bypass set_src_ptr_next_string call
@clear_next:
        jsr     set_src_ptr_next_string ; Move src_ptr past relocation address and to next string
@clear_next_2:
        jsr     check_src_ptr
        bcs     @mark                   ; No more to clear
        jsr     set_src_ptr_relocation_address
        lda     #0
        sta     (src_ptr),y             ; Set to 0
        jmp     @clear_next

; Phase 2: Find all string variables and mark each string in memory.

@mark:
        ldax    variable_name_table_ptr ; Prepare to scan variables
        jsr     initialize_name_ptr
@mark_next:
        jsr     advance_name_ptr
        bcs     @calculate
        jsr     find_variable_data
        beq     @mark_next              ; Not a string; move on to the next one
        jsr     set_src_ptr_relocation_address  ; Add length to src_ptr; Y points to relocation address
        lda     #1
        sta     (src_ptr),y             ; Store 1 into the relocation address field.
        bne     @mark_next

; Phase 3: Calculate the relocation address for each string.

@calculate:
        mvax    string_ptr, src_ptr
        mvax    free_ptr, dst_ptr
        bne     @calculate_next_2       ; Unconditional bypass set_src_ptr_next_string call
@calculate_next:
        jsr     set_src_ptr_next_string ; Move src_ptr past relocation address and to next string
@calculate_next_2:
        jsr     check_src_ptr
        bcs     @update                 ; No more strings
        jsr     set_src_ptr_relocation_address
        lda     (src_ptr),y             ; Marked?
        beq     @calculate_next         ; Nope, move on
        lda     dst_ptr                 ; Save current value of dst_ptr into relocation address
        sta     (src_ptr),y
        iny
        lda     dst_ptr+1
        sta     (src_ptr),y
        txa                             ; Length is still in X from the call to set_src_ptr_relocation_address
        jsr     add_dst_ptr             ; Add to dst_ptr
        lda     #STRING_EXTRA
        jsr     add_dst_ptr             ; Allow for string overhead
        jmp     @calculate_next

; Phase 4: Update string variables to point to the new addresses.
; After calculating relocation addresses, dst_ptr now points to an address one byte beyond the last string,
; so the size of the string space is dst_ptr - free_ptr, and the new value of string_ptr is himem_ptr minus that size:
; string_ptr = himem_ptr - (dst_ptr - free_ptr). Store new string_ptr value in DE.

@update:
        sec                             ; Subtract free_ptr from dst_ptr to get size of string space
        lda     dst_ptr
        sbc     free_ptr
        sta     size                    ; Save in size for now
        lda     dst_ptr+1
        sbc     free_ptr+1
        sta     size+1
        sec                             ; Subtract size from himem_ptr to get the new string_ptr value
        lda     himem_ptr
        sbc     size
        sta     D                       ; Store in DE
        lda     himem_ptr+1
        sbc     size+1
        sta     E
        ldax    variable_name_table_ptr ; Prepare to scan variables
        jsr     initialize_name_ptr
@update_next:
        jsr     advance_name_ptr
        bcs     @relocate
        jsr     find_variable_data
        beq     @update_next            ; Not a string; move on to the next one
        jsr     set_src_ptr_relocation_address  ; Add length to src_ptr; Y points to relocation address
        sec                             ; Do relocation address - free_ptr + new string_ptr and into variable address
        lda     (src_ptr),y
        sbc     free_ptr
        pha                             ; Save low byte onto stack
        iny                             ; Y=1
        lda     (src_ptr),y
        sbc     free_ptr+1
        tax                             ; Save high byte in X
        clc                             ; Now add the new string_ptr in DE to get the final address
        pla                             ; Get back low byte
        adc     D
        dey                             ; Y=0
        sta     (name_ptr),y
        txa                             ; Get back high byte
        adc     E
        iny                             ; Y=1
        sta     (name_ptr),y
        jmp     @update_next

; Phase 5: Move each still-referenced string down to its relocation address.
; For each string we take one of two paths. If it's marked, we call copy to move its length byte and data, which
; will leave src_ptr pointing to its relocation address. If it's not marked, we just add the length plus one to
; src_ptr, which also leaves src_ptr pointing to the relocation address. We don't need to actually copy the
; relocation address itself, as it's not needed after this phase.

@relocate:
        mvax    string_ptr, src_ptr
        bne     @relocate_next_2        ; Unconditional bypass set_src_ptr_next_string call 
@relocate_next:
        jsr     set_src_ptr_next_string ; Move src_ptr past relocation address and to next string
@relocate_next_2:        
        jsr     check_src_ptr
        bcs     @shift                  ; No more strings
        jsr     set_src_ptr_relocation_address
        lda     (src_ptr),y             ; Marked?
        beq     @relocate_next          ; Nope, move on
        sta     dst_ptr                 ; Save relocation address into dst_ptr
        iny
        lda     (src_ptr),y
        sta     dst_ptr+1

; src_ptr now points to the relocation address, so subtract the length (still in X) and 1 (length byte) to recover
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
        ldx     #0                      ; Initialize high byte to 0
        tay                             ; This effctively tests A = 0
        bne     @skip_inx               ; Size didn't roll over to 0 so no need to increment high byte
        inx
@skip_inx:
        jsr     copy                    ; Copy from src_ptr to dst_ptr
        jmp     @relocate_next

; Phase 6: All the strings have been relocated to free_ptr.
; The new value of string_ptr is in DE. Subtract it from himem_ptr to get the size to copy.

@shift:
        sec                             ; Do himem_ptr - DE and store in size
        lda     himem_ptr
        sbc     D
        pha                             ; Save for call to copy
        lda     himem_ptr+1
        sbc     E
        pha
        mvax    DE, string_ptr          ; Set up new string_ptr
        stax    dst_ptr                 ; Also destination for copy
        mvax    free_ptr, src_ptr
        plax                            ; Get the size we pushed earlier
        jsr     copy
        rts                             ; All done!

; Rebases name_ptr so it points to the variable data.
; Returns the type of variable in A.

.assert TYPE_NUMBER = $00, error
.assert TYPE_STRING = $01, error

find_variable_data:
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
        ldy     #0                      ; Set up src_ptr
        lda     (name_ptr),y
        sta     src_ptr
        iny
        lda     (name_ptr),y
        sta     src_ptr+1
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

; Adds 2 bytes to src_ptr to move past the relocation address and to the next string.

set_src_ptr_next_string:
        lda     #STRING_EXTRA - 2       ; Subtract 1 for string length and 1 more because carry will be set
        bne     add_src_ptr_plus_one

; Adds the length of the string referenced by src_ptr plus one to src_ptr, so that src_ptr points to
; the relocation address. Returns the string length in X and 0 in Y.

set_src_ptr_relocation_address:
        ldy     #0
        lda     (src_ptr),y             ; Load length first
        tax                             ; Move into X in case someone wants it later

; Fall through

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

; Adds the value in A to dst_ptr.

add_dst_ptr:
        clc
        adc     dst_ptr
        sta     dst_ptr
        bcc     @done
        inc     dst_ptr+1
@done:
        rts
