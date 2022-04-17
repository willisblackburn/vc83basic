; cc65 runtime
.include "zeropage.inc"

.include "target.inc"
.include "basic.inc"

.zeropage

name_ptr: .res 2

.code

; Matches the input against names from a table.
; Each name table entry consists of a name, which is a sequence of character bytes in the range $20-$5F,
; followed by any number of extra data bytes. The last byte of the name table entry must have bit 7 set.
; name_ptr = pointer to the first entry of the name table
; r = read position in buffer (updated on success)
; Returns carry clear if the name matched and carry set if it didn't match any name.
; On match, returns the number of the matched name in A and the next position in the name table
; after the matched name in Y.
; If no match, then A is the number of names in the name table and name_ptr points to the 0 at the end of the table.

find_name:

@index = tmp2

        lda     #0              ; Name table index
        sta     @index      
@next_name:
        ldy     #0              ; Y is the read position in the name table entry
        lda     (name_ptr),y    ; Get name character
        beq     @error          ; If it's 0 then out of names to match
        jsr     match_character_sequence
        bcc     @match
        inc     @index          ; Increment name table index; doesn't affect carry
        bcs     @next_name 

@error:
        sec                     ; Signal failure
@match:
        lda     @index          ; Return number of matched name in A
        rts

; Matches a character sequence from the name table with characters from buffer.
; name_ptr = pointer to the current name table entry
; Y = the current read position in the name table entry
; r = read position in buffer (updated on success)
; Returns carry clear if the name matched and carry set if it didn't match any name.
; On success, Y will point to the next byte past the matched word, and name_ptr will be unchanged.
; On failure, name_ptr will be set to the next name table entry.

match_character_sequence:

@last = tmp1

        ldx     r               ; Load read position into X
@next_character:
        lda     (name_ptr),y    ; Get name character
        sta     @last           ; It's now the last-read character
        and     #$60            ; Check if it's a string literal character
        beq     @non_literal
        lda     @last           ; Reload last-read character
        and     #$7F            ; Clear bit 7, if it's set
        cmp     buffer,x        ; Compare with character from buffer
        bne     @advance_y_next_entry   ; Doesn't match
        iny                     ; Next position
        inx
        lda     @last           ; Reload character once more
        bpl     @next_character ; If bit 7 not set then continue

; We've reached a character in the name table entry with bit 7 set and everything has matched so far.
; Check for name continuation. If the name continues, then return no match. Y already points to next entry.

        jsr     check_name_continuation
        bcs     @match
        jmp     @no_match

; We're reached a non-literal character and everything has matched so far.
; Check for name continuation. If the name continues, then advance to next entry and return no match.

@non_literal:
        jsr     check_name_continuation
        bcs     @match

@advance_y_next_entry:
        lda     (name_ptr),y    ; Load current position
        tax                     ; Temporarily park in X
        iny                     ; Advance past
        txa                     ; Get the loaded character back to check bit 7
        bpl     @advance_y_next_entry   ; Keep searching if bit 7 not set

@no_match:
        tya                     ; Y is now the offset of the next rule; add to name_ptr
        clc                     ; Add to name_ptr to get updated name_ptr
        adc     name_ptr      
        sta     name_ptr
        bcc     @done           ; Don't have to increment high byte
        inc     name_ptr+1
@done:
        sec                     ; Set carry to indicate failure
        rts

@match:
        stx     r               ; Update r
        clc                     ; Signal success
        rts

; Checks if the character at position X in buffer is a continuation of a name at position X-1.
; We consider it a continuation if the X-1 character was a name character and the X character is also
; a name character.
; Returns carry clear if the name is a continuation, carry set if it is not.
; X SAFE, Y SAFE

check_name_continuation:
        lda     buffer-1,x      ; Get last matched character
        jsr     is_name_character
        bcs     @done           ; Was not a name character, don't need to check the next one
        lda     buffer,x        ; Get this character
        jsr     is_name_character
@done:
        rts

; Checks if the character A is a name character. A name character is 'A'-'Z', '0'-'9', or '$'.
; Returns carry clear if it is, carry set if not.
; X SAFE, Y SAFE

is_name_character:
        sec                     ; Prepare for subtract
        sbc     #'$'            ; First check '$' case        
        cmp     #1              ; Sets carry if char was >'$'
        bcc     @done           ; It was '$'
        sbc     #'0'-'$'        ; Check range 0-9
        cmp     #10             ; Sets carry if char was >'9'
        bcc     @done           ; It was in range 0-9
        sbc     #'A'-'0'        ; Check range 'A'-'Z'
        cmp     #26             ; Sets carry if char was >'Z'
@done:
        rts
