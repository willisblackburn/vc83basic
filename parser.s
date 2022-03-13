; cc65 runtime
.include "zeropage.inc"

.include "target.inc"
.include "basic.inc"

.zeropage

; Read index.
r: .res 1
; Write index.
w: .res 1

signature: .res 2
argument_index: .res 1

.code

; Parses a number from the buffer.
; If the first character is not a number, then return an error. Otherwise, parse up to the first non-digit.
; r = the read index
; Returns the number in AX, carry clear if ok, carry set if error

parse_number:

@digit_value = tmp1

        jsr     skip_whitespace
        ldy     r               ; Use Y to index buffer
        lda     #0              ; Intialize the value to 0
        tax
@next:
        cpy     buffer_length   ; At the end of the line yet?
        beq     @finish         ; Yes, return
        pha                     ; Save A (low byte of value)
        lda     buffer,y
        jsr     char_to_digit   ; Doesn't touch X
        sta     @digit_value    ; Store the digit value
        pla                     ; Retrieve the low byte of value
        bcs     @finish         ; If there was an error in char_to_digit, stop parsing
        iny                     ; No error, increment read index
        jsr     mul10           ; Multiply the value by 10
        clc
        adc     @digit_value    ; Add the digit value
        bcc     @next           ; If carry clear then next digit
        inx                     ; Otherwise increment high byte
        jmp     @next

@finish:
        cpy     r               ; Did we parse anything?
        beq     @nothing        ; Nope
        sty     r               ; Update read index
        clc                     ; Clear carry to signal OK
        rts

@nothing:
        sec                     ; Set carry to signal error
        rts

; Converts the character in A into a digit.
; This function only uses A and does not touch X or Y.
; Returns the digit in A, carry clear if ok, carry set if error

char_to_digit:
        sec                     ; Set carry
        sbc     #'0'            ; Subtract '0'; maps valid values to range 0-9 and other values to 10-255
        cmp     #10             ; Sets carry if it's in the 10-255 range
        rts

; Parses and tokenizes a statement.
; The last byte of the buffer should be 0, which won't match anything. This avoids the need to keep checking
; the buffer length.
; r = read index into the bffer
; Returns carry clear if the input matched a rule and the index of that rule in A, 
; or carry set if it didn't match any syntax rule.

parse_statement:

@save_y = tmp1

        lda     #<statement_name_table
        ldx     #>statement_name_table
        jsr     find_name       ; Sets name_table and name_index and Y points to next byte in name table
        bcs     @error
        sty     @save_y         ; Remember name table entry index
        pha                     ; Push the returned name index
        ; jsr     encode_statement_name   ; Encode a statement name
        lda     #0
        sta     argument_index  ; Start out at argument index 0
        

; After matching a name, Y will point to one of:
; 1. 0, meaning we matched the last entry and there are no arguments.
; 2. A character, which must be the *next* entry.
; 3. An argument placeholder. In this case we keep reading arguments and/or character sequences.

        lda     (name_table),y  ; Check if there are any arguments to read
        pha
        and     #$70            ; If we're left with $10 then read arguments
        cmp     #$10
        pla
        and     #$0F            ; How many arguments to parse?
        jsr     parse_arguments        
        bcs     @error




; @arguments:
;         lda     save_name_table_byte
;         and     #$0F            ; Find out how many arguments we have to read
;         sta     argument_read_count
;         beq     @no_more_arguments
; @next_argument:
;         jsr     parse_argument
;         dec     argument_read_count
;         beq     @no_more_arguments
;         jsr     parse_argument_separator
;         jmp     @next_argument






        and     #$70            



;         sta     ptr1            ; Syntax table pointer into ptr1        
;         stx     ptr1+1
;         ldy     #2
;         lda     (ptr1),y        ; High byte of signature table address
;         sta     ptr2+1          ; Store into ptr2
;         dey        
;         lda     (ptr1),y        ; Low byte
;         sta     ptr2            
;         clc
;         adc     #2              ; Advance ptr1 past the signature table address
;         sta     ptr1
;         txa                     ; High byte is still in X
;         adc     #0              ; Add the carry to it
;         sta     ptr1+1          ; Store back
;         lda     #0              ; Name index
;         sta     tmp1            ; Maintain in tmp1
; @next_syntax_rule:
;         ldx     r               ; Use X to index buffer
;         ldy     #0              ; Y will index the syntax rule pointed to by ptr1
;         sty     tmp2            ; tmp2 is the current signature table entry
;         lda     (ptr1),y        ; See what we have
;         beq     @fail           ; If it was 0 then we've reached the end of the table
;         iny                     ; Advance index
;         pha                     ; Save the value on the stack; we'll restore to check end of rule bit later
;         and     #$7F            ; 
; ;        bit     #$60            ; Is it the start of a string literal?
;         bne     @not_literal    ; No
; @next_literal:
;         cmp     buffer,x        ; Compare literal 
;         inx
        



; @not_literal:


;         sty     tmp3            ; Park Y in tmp3 and re-use Y to access the signature table
;         ldy     tmp2
;         and     #$07            ; Low 3 bits are the number of signature table entries to read
;         beq     @skip_arguments ; No arguments (this is the mechanism that )
;         sta     tmp4            ; tmp4 is the number of signature table arguments to read
; @next_argument:
;         beq     @finish_arguments ; No more arguments
        



;         dec     tmp4            ; Decrement the number of signature table entries

; @skip_arguments:

; @finish_arguments:




;         jsr     parse_string_literal    ; Try to parse as a string literal
        

@error:
        sec                     ; Set carry to indicate failure
        rts


parse_string_literal:
        rts


argument_type_vectors:
        .word   parse_error
        .word   parse_expression
        .word   parse_expression
        .word   parse_expression
        .word   parse_expression
        .word   parse_error
        .word   parse_error
        .word   parse_error
        .word   parse_error
        .word   parse_error
        .word   parse_error
        .word   parse_error
        .word   parse_error
        .word   parse_error
        .word   parse_error
        .word   parse_error

; Parses arguments from the buffer and tokenizes them.
; Arguments must be separated by ','.
; In this function we don't pay attention to the name table anymore; we're only concerned with parsing some
; number of arguments based on the types in the signature table.
; A = the number of arguments to parse
; signature = the address of the signature
; argument_index = where to start reading arguments from signature table (modified)
; r = the read index into buffer (modified)
; w = the token write index (modified)

parse_arguments:

@argument_count = tmp2

        sta     @argument_count
        beq     @done
@next_argument:
        ldy     argument_index  ; Use Y to index signature
        lda     (signature),y   ; Load argument
        and     $0F             ; Isolate argument type
        tay
        lda     #<argument_type_vectors
        ldx     #>argument_type_vectors
        jsr     jsr_indexed_vector
        bcs     @error
        inc     argument_index
        dec     @argument_count
        lda     @argument_count
        beq     @done
        jsr     parse_argument_separator
        jmp     @next_argument
@done:
        rts

@error:
        sec
        rts

; Placeholder handler that just signals an error.

parse_error:
        sec
        rts

; Parses and tokenizes a expression.
; r = the read index (will be modified)
; w = the token write index (will be modified)

parse_expression:
        jsr     parse_number
        bcs     @error
        jsr     encode_int      ; Will set carry if fail
@error:
        rts

; Parses a mandatory comma beween arguments.
; r = the read index (modified)
; Returns carry clear if the ',' was found or carry set if it was not.

parse_argument_separator:
        jsr     skip_whitespace
        ldy     r
        lda     buffer,y
        cmp     #','
        bne     @error
        iny
        sty     r
        clc
        rts

@error:
        sec
        rts

; Skip past any whitespace in the buffer.
; r = the read index (modified)

skip_whitespace:
        ldy     r               ; Use Y to index buffer
@next:
        lda     buffer,y
        iny
        cmp     #' '
        beq     @next
        dey                     ; It wasn't whitespace so go back
        sty     r               ; Update read index
        rts


