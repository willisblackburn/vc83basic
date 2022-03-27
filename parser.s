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

; All "parse" functions use:
; r = the read index into buffer (modified)
; w = the token write index (modified)

; Parses a number from the buffer.
; 

parse_number:
        jsr     read_number
        bcs     @error
        jsr     encode_number   ; Will set carry if fail
@error:
        rts

; Reads a number from the buffer.
; If the first character is not a number, then return an error. Otherwise, read up to the first non-digit.
; r = the read index
; Returns the number in AX, carry clear if ok, carry set if error

read_number:

@digit_value = tmp1

        jsr     skip_whitespace
        ldy     r               ; Use Y to index buffer (since AX will hold the number)
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
; name = pointer to the first entry of the name table
; signature = pointer to the first entry of the signature table
; Returns carry clear if the input matched a rule and the index of that rule in A, 
; or carry set if it didn't match any syntax rule.

parse_statement:

@save_y = tmp3

        jsr     skip_whitespace
        jsr     find_name       ; Sets Y to next byte in name table entry
        sty     @save_y         ; Remember the Y position
        bcs     @error
        pha                     ; Push the returned name index
        jsr     encode_byte     ; Encode a statement name
        pla                     ; Get the name index back before checking error
        bcs     @error          ; encode_byte error
        asl                     ; Calculate the address of the signature; each name gets 2 signature bytes
        adc     signature       ; Carry clear because encode_byte succeeded
        sta     signature
        lda     #0
        sta     argument_index  ; Opportunistically set argument_index to 0
        adc     signature+1
        sta     signature+1
        ldy     @save_y

; After a character sequence, Y will point to one of:
; 1. 0, meaning we matched the last sequence in the last name table entry; stop.
; 2. A character, which must be the *next* entry; stop.
; 3. An argument placeholder. In this case we keep reading arguments and/or character sequences.

@after_character_sequence:
        lda     (name_table),y  ; Check if there are any arguments to read
        beq     @success
        and     #$60            ; If byte AND $60 is non-zero then it's another character sequence.
        bne     @success

; The next byte must be arguments.

@arguments:
        lda     (name_table),y  ; Re-read name table byte
        pha                     ; Remember it in order to check bit 7 later
        iny
        and     #$0F            ; How many arguments to parse?
        sty     @save_y         ; parse_arguments needs Y
        jsr     parse_arguments
        pla                     ; Pop name table byte before checking for error       
        bcs     @error
        bmi     @success        ; If bit 7 set then all done

; Just finished arguments. If there's a character sequence here then parse it, otherwise parse another argument.

        ldy     @save_y
        lda     (name_table),y
        and     #$60            ; Is it a character sequence?
        beq     @arguments      ; Nope, go handle more arguments (Y is good)
        jsr     skip_whitespace
        jsr     match_character_sequence    ; Will advance Y past the matched sequence
        bcc     @after_character_sequence   ; If matched then continue, else fall through to @error (Y is good)

; We never jump to @error without carry being set so don't have to set it again.

@error:
        rts

@success:
        clc
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

parse_expression:
        jsr     parse_number
@error:
        rts

; Parses a mandatory comma beween arguments. Does not write any tokens.
; Returns carry clear if the ',' was found or carry set if it was not.

parse_argument_separator:
        jsr     skip_whitespace
        ldx     r
        lda     buffer,x
        cmp     #','
        bne     @error
        inx
        stx     r
        clc
        rts

@error:
        sec
        rts

; Skip past any whitespace in the buffer.
; This function is NOT exported because we want other modules to call parsing funtions, not this function.
; r = the read index (modified)

skip_whitespace:
        ldx     r               ; Use Y to index buffer
@next:
        lda     buffer,x
        inx
        cmp     #' '
        beq     @next
        dex                     ; It wasn't whitespace so go back
        stx     r               ; Update read index
        rts
