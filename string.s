.include "macros.inc"
.include "basic.inc"

; Loads a string into one of the two S registers.
; Returns length in A and a pointer to the string data in the selected S register: either S0 for load_s0, or the
; register identified by Y for load_sy.
; AX = a pointer to the string to load
; BC SAFE

load_s0:
        ldy     #S0
load_sy:
        stax    DE                      ; DE is a temporary pointer
        stx     1,y                     ; Store high byte of string address
        tax                             ; Move low byte into X since I'm about to clobber A
        ora     E                       ; Check for null
        beq     @null_string            ; A is conveniently 0 for return
        inx                             ; Increment low byte of address
        stx     0,y                     ; Store low byte of string address
        bne     @skip_inc               ; Low byte didn't roll over so don't have to adjust high byte
        ldx     E                       ; High byte is in E, so re-load and re-store
        inx
        stx     1,y
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
        beq     @finish                 ; Was zero, definitely finished
        cmp     D                       ; Was it the terminator?
        bne     @not_terminator         ; Nope
        cmp     #'"'                    ; Was the terminator also double quote?
        bne     @finish                 ; Nope; we're finished
        inc     B                       ; Always skip over this quote
        iny                             ; Increment Y in order to check the next character
        cmp     (src_ptr),y             ; Is it also a double quote?
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
; BC SAFE, DE SAFE

string_alloc:
        pha                             ; Save the original length
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
        pla                             ; Recover length from stack
        cpx     free_ptr+1              ; Compare high byte vs. free_ptr
        bcc     @error                  ; New string_ptr high byte < free_ptr; it's definitely an error
        bne     @string_ptr_ok          ; If it's greater then it's definitely okay
        cpy     free_ptr
        bcc     @error                  ; Less than free_ptr is an error, but >= is okay
@string_ptr_ok:
        sty     string_ptr              ; Proposed string_ptr >= free_ptr; go update it
        stx     string_ptr+1
        ldy     #0                      ; Offset of length
        sta     (string_ptr),y          ; Set the length
        ldax    string_ptr              ; Return pointer in AX
        clc                             ; Signal success
        rts

@error:
        sec
        rts

; Compacts the string space.
; Moves all strings that are still referenced by variables (or from the value stack) to their highest possible
; address. The algorithm uses two bytes after the end of each string to store its relocation address. The
; string_alloc function allocates 3 (STACK_EXTRA) extra bytes to accommodate the length of the string and the two-byte
; relocation address.

; Logic depends on being able to add string length + 3 to get to next string.
.assert STRING_EXTRA = 3, error

compact:

; Phase 1: Set the relocation address low byte of all strings to 0.

        debug $00
        mvax    string_ptr, src_ptr     ; Use src_ptr to scan string space
        bne     @clear_next_2           ; Unconditional bypass set_src_ptr_next_string call
@clear_next:
        jsr     set_src_ptr_next_string ; Move src_ptr past relocation address and to next string
@clear_next_2:
        ldax src_ptr
        debug $01
        jsr     check_src_ptr
        debug $02
        bcs     @mark                   ; No more to clear
        jsr     set_src_ptr_relocation_address
        ldax src_ptr
        debug $03
        lda     #0
        sta     (src_ptr),y             ; Set to 0
        jmp     @clear_next

; Phase 2: Find all string variables and mark each string in memory.

@mark:
        debug $10
        ldax    variable_name_table_ptr ; Prepare to scan variables
        jsr     initialize_name_ptr
@mark_next:
        jsr     advance_name_ptr
        debug $11
        bcs     @calculate
        jsr     find_variable_data
        bne     @mark_next              ; Not a string; move on to the next one
        jsr     set_src_ptr_relocation_address  ; Add length to src_ptr; Y points to relocation address
        sta     (src_ptr),y             ; Store 1 into the relocation address field.
        bne     @mark_next

; Phase 3: Calculate the relocation address for each string.

@calculate:
        debug $20
        mvax    string_ptr, src_ptr
        mvax    free_ptr, dst_ptr
        bne     @calculate_next_2       ; Unconditional bypass set_src_ptr_next_string call
@calculate_next:
        jsr     set_src_ptr_next_string ; Move src_ptr past relocation address and to next string
@calculate_next_2:
        ldax src_ptr
        debug $21
        jsr     check_src_ptr
        debug $22
        bcs     @update                 ; No more strings
        jsr     set_src_ptr_relocation_address
        ldax src_ptr
        debug $23
        lda     (src_ptr),y             ; Marked?
        beq     @calculate_next         ; Nope, move on
        lda     dst_ptr                 ; Save current value of dst_ptr into relocation address
        sta     (src_ptr),y
        lda     dst_ptr+1
        iny
        sta     (src_ptr),y
        txa                             ; Length is still in X from the call to set_src_ptr_relocation_address
        jsr     add_dst_ptr             ; Add to dst_ptr
        lda     #STRING_EXTRA
        jsr     add_dst_ptr             ; Allow for string overhead
        jmp     @calculate_next

; Phase 4: Update string variables to point to the new addresses.

@update:
        debug $30
        ldax    variable_name_table_ptr ; Prepare to scan variables
        jsr     initialize_name_ptr
@update_next:
        jsr     advance_name_ptr
        debug $31
        bcs     @relocate
        jsr     find_variable_data
        bne     @update_next            ; Not a string; move on to the next one
        jsr     set_src_ptr_relocation_address  ; Add length to src_ptr; Y points to relocation address
        lda     (src_ptr),y             ; Copy address from relocation address to variable data
        sta     (name_ptr),y
        iny
        lda     (src_ptr),y
        sta     (name_ptr),y
        jmp     @update_next

; Phase 5: Move each still-referenced string down to its relocation address.

@relocate:
        debug $40
        mvax    string_ptr, src_ptr
        bne     @relocate_next_2        ; Unconditional bypass set_src_ptr_next_string call 
@relocate_next:
        jsr     set_src_ptr_next_string ; Move src_ptr past relocation address and to next string
@relocate_next_2:        
        jsr     check_src_ptr
        debug $41
        bcs     @shift                  ; No more strings
        jsr     set_src_ptr_relocation_address
        lda     (src_ptr),y             ; Marked?
        beq     @relocate_next          ; Nope, move on
        sta     dst_ptr                 ; Save relocation address into dst_ptr
        iny
        lda     (src_ptr),y
        inx                             ; Length is still in X; add 1 to account for length byte
        txa                             ; Low byte of size
        bne     @no_size_rollover       ; Was not 0 so adding 1 didn't cause rollover
        inx                             ; Did rollover, so A is 0, and make high byte 1
@no_size_rollover:
        jsr     copy                    ; Copy AX bytes from src_ptr to dst_ptr
        jmp     @relocate_next

; Phase 6: All the strings have been relocated to free_ptr.
; Calculate the new value of string_ptr and copy all the data up to that address.
; After calling copy, dst_ptr now points to an address one byte beyond the last string, so the size of the
; string space is dst_ptr - free_ptr, and the new value of string_ptr is himem_ptr minus that size.
; string_ptr = himem_ptr - (dst_ptr - free_ptr)

@shift:
        debug $50
        sec                             ; Prepare for subtract
        lda     dst_ptr
        sbc     free_ptr
        sta     size
        lda     dst_ptr+1
        sbc     free_ptr+1
        sta     size+1
        sec                             ; Prepare for second subtract
        lda     himem_ptr
        sbc     size
        sta     string_ptr              ; New value of string_ptr
        sta     dst_ptr                 ; And destination of copy
        lda     himem_ptr+1
        sbc     size+1
        sta     string_ptr+1
        sta     dst_ptr+1
        mvax    free_ptr, src_ptr
        debug $60
        jsr     copy_size
        rts                             ; All done!

; Rebases name_ptr so it points to the variable data.
; Returns the type of variable in A.

.assert TYPE_NUM = 0, error
.assert TYPE_STRING = 1, error

find_variable_data:
        ldy     #$FF                    ; Scan forward to find the end of the name
@next:
        iny
        lda     (name_ptr),y
        bpl     @next
        ldx     #TYPE_NUM
        cmp     #'$' | NT_STOP          ; Was it a string?
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

; Adds the length of the string referenced by src_ptr plus one to src_ptr, so that src_ptr points to
; the relocation address. Returns the string length in X and 0 in Y.

set_src_ptr_relocation_address:
        ldy     #0
        lda     (src_ptr),y             ; Load length first
        tax                             ; Move into X in case someone wants it later
        jmp     add_src_ptr_plus_one

; Adds 2 bytes to src_ptr to move past the relocation address and to the next string.

set_src_ptr_next_string:
        lda     #STRING_EXTRA - 2       ; Subtract 1 for string length and 1 again because carry will be set

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
