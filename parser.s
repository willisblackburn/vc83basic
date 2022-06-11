.include "macros.inc"
.include "basic.inc"

.zeropage

; Read position
r: .res 1
; Write position
w: .res 1

signature_ptr: .res 2
argument_index: .res 1
argument_count: .res 1

; The line number we read from the input line
parsed_line_number: .res 2

.code

; All "parse" functions use:
; buffer = the buffer containing the user-entered program source
; r = the read position in buffer (modified on success)
; line_buffer = the buffer containing the tokenized output
; w = the token write position in line_buffer (modified on success)

; Reads a number from the buffer.
; If the first character is not a number, then return an error. Otherwise, read up to the first non-digit.
; r = the read position in buffer
; Returns the number in AX, carry clear if ok, carry set if error

read_number:
        ldy     r                       ; Use Y to index buffer (since AX will hold the number)
        lda     #0                      ; Intialize the value to 0
        tax
@next:
        pha                             ; Save A (low byte of value)
        lda     buffer,y    
        jsr     char_to_digit           ; X SAFE function
        sta     B                       ; Store the digit value
        pla                             ; Retrieve the low byte of value
        bcs     @finish                 ; If there was an error in char_to_digit, stop parsing
        iny                             ; No error, increment read position
        jsr     mul10                   ; Multiply the value by 10 (preserves Y)
        clc
        adc     B                       ; Add the digit value
        bcc     @next                   ; If carry clear then next digit
        inx                             ; Otherwise increment high byte
        jmp     @next

@finish:
        cpy     r                       ; Did we parse anything?
        beq     @nothing                ; Nope
        sty     r                       ; Update read position
        clc                             ; Clear carry to signal OK
        rts

@nothing:
        sec                             ; Set carry to signal error
        rts

; Converts the character in A into a digit.
; Returns the digit in A, carry clear if ok, carry set if error
; X SAFE, Y SAFE

char_to_digit:
        sec                             ; Set carry
        sbc     #'0'                    ; Subtract '0'; maps valid values to range 0-9 and other values to 10-255
        cmp     #10                     ; Sets carry if it's in the 10-255 range
        rts

; Parses and tokenizes a syntax element starting with a name.
; The last byte of buffer should be 0, which won't match anything. This avoids the need to keep checking
; the buffer length.
; This function is called recursively. It sets up name_ptr and Y and saves them on the stack prior to calling
; other functions so that those functions can call back in to this one.
; AX = pointer to the first entry of the name table
; signature_ptr = pointer to the first entry of the signature table
; Returns carry clear if the input matched a rule, or carry set if it didn't match any syntax rule.

parse_element:

; This whole first section uses Y to track the parse position in the name table entry pointed to by name_ptr.

        jsr     find_name               ; Sets Y to next byte in name table entry (AX passed to find_name)
        bcs     @error
        pha                             ; Save the returned name index
        jsr     encode_byte             ; Encode the statement name
        pla                             ; Recover the name index (doesn't affect carry)
        bcs     @error                  ; encode_byte error
        asl                             ; Calculate the address of the signature; each name gets 2 signature bytes
        adc     signature_ptr           ; Carry already clear because encode_byte succeeded
        sta     signature_ptr   
        lda     #0  
        sta     argument_index          ; Opportunistically set argument_index to 0
        adc     signature_ptr+1
        sta     signature_ptr+1

; After a character sequence, Y will point to one of:
; 1. 0, meaning we matched the last sequence in the last name table entry; stop.
; 2. A character, which must be the *next* entry; stop.
; 3. An argument placeholder. In this case we keep reading arguments and/or character sequences.

@after_character_sequence:
        lda     (name_ptr),y            ; Check if there are any arguments to read
        beq     @success
        and     #$60                    ; If byte AND $60 is non-zero then it's another character sequence.
        bne     @success

; The next byte must be arguments.

@arguments:
        ldphaa  name_ptr                ; Save name_ptr, signature_ptr, and Y on the stack
        ldphaa  signature_ptr
        tya
        pha     
        lda     (name_ptr),y            ; Re-read name table byte
        and     #$0F                    ; How many arguments to parse?
        jsr     parse_arguments
        pla                             ; Restore vars from stack before
        tay
        plstaa  signature_ptr
        plstaa  name_ptr
        bcs     @error
        lda     (name_ptr),y            ; Re-read name table byte
        bmi     @success                ; If bit 7 set then all done
        iny                             ; Advance Y to the next position in the name table entry

; Just finished arguments. If there's a character sequence here then parse it, otherwise parse another argument.
; This section also uses Y to track the parse position.

        lda     (name_ptr),y
        and     #$60                    ; Is it a character sequence?
        beq     @arguments              ; Nope, go handle more arguments (Y is good)
        jsr     skip_whitespace
        jsr     match_character_sequence    ; Will advance Y past the matched sequence
        bcc     @after_character_sequence   ; If matched then continue, else fall through to @error (Y is good)

@success:
        clc

; We never jump to @error without carry being set so don't have to set it again.

@error:
        rts

argument_type_vectors:
        .word   parse_error
        .word   parse_expression
        .word   parse_expression
        .word   parse_expression
        .word   parse_expression
        .word   parse_error
        .word   parse_error
        .word   parse_expression
        .word   parse_variable
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
; signature_ptr = the address of the signature
; argument_index = where to start reading arguments from signature table (modified)

parse_arguments:
        sta     argument_count
        beq     @done                   ; Eject if argument count is 0
@next_argument:
        ldy     argument_index          ; Use Y to index signature
        lda     (signature_ptr),y       ; Load argument
        and     #$0F                    ; Isolate argument type
        tay
        ldax    #argument_type_vectors
        jsr     invoke_indexed_vector
        bcs     @error
        inc     argument_index
        dec     argument_count
        beq     @done                   ; Note carry must be clear here
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
; This functinon handles skipping whitespace for ALL expression elements.

parse_expression:
        jsr     skip_whitespace
        jsr     parse_number
        bcc     @done
        jsr     parse_variable
@done:
        rts

; Parses a number from the buffer.

parse_number:
        jsr     read_number
        bcs     @error
        jsr     encode_number           ; Will set carry if fail
@error:
        rts

; Parses a variable name.
; Tries to match the current buffer at position r with the names in the variable name table.
; If the name is not found, then extends the variable name table.

parse_variable:
        jsr     skip_whitespace
        ldx     r                       ; Load read position into X
        lda     buffer,x                ; Load current character
        sec
        sbc     #'A'                    ; Check if first character is in range A-Z
        cmp     #26
        bcs     @done
        ldax    variable_name_table_ptr
        jsr     find_name
        bcc     @found
        jsr     add_variable
        bcs     @done
@found:
        jsr     encode_variable       
@done:
        rts

; Parses a mandatory comma beween arguments. Does not write any tokens.
; Returns carry clear if the ',' was found or carry set if it was not.
; Y SAFE

parse_argument_separator:
        jsr     skip_whitespace
        ldx     r
        lda     buffer,x
        cmp     #','                    ; Sets carry if character was ','
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
; r = the read position (modified)
; Y SAFE, BC SAFE, DE SAFE

skip_whitespace:
        ldx     r                       ; Use X to index buffer
@next:      
        lda     buffer,x        
        inx     
        cmp     #' '        
        beq     @next       
        dex                             ; It wasn't whitespace so go back
        stx     r                       ; Update read position
        rts
