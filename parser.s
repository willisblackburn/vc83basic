.include "macros.inc"
.include "basic.inc"

.zeropage

; Read/write position in buffer
bp: .res 1

; The number of arguments that parse_argument_list is parsing
argument_count: .res 1

.code

; All "parse" functions use:
; buffer = the buffer containing the user-entered program source
; bp = the read position in buffer (modified on success)
; line_buffer = the buffer containing the tokenized output
; lp = the token write position in line_buffer (modified on success)

; Reads a number from the buffer.
; If the first character is not a number, then return an error. Otherwise, read up to the first non-digit.
; bp = the read position in buffer
; Returns the number in AX, carry clear if ok, carry set if error

read_number:
        jsr     skip_whitespace         ; TODO: can check return here to see if it's a number
        ldy     bp                      ; Use Y to index buffer (since AX will hold the number)
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
        cpy     bp                      ; Did we parse anything?
        beq     @nothing                ; Nope
        sty     bp                      ; Update read position
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

; Parses a line from the buffer. The line is an optional line number followed by statements.
; If the line number is missing, set it to -1.

parse_line:
        mva     #0, bp                  ; Initialize the read pointer
        mva     #Line::data, lp         ; Initialize write pointer
        jsr     read_number             ; Leaves line number in AX and bp points to next character in buffer
        bcc     @store_line_number      ; Line number was provided so store it
        lda     #$FF                    ; Otherwise store -1 ($FFFF) instead
        tax
@store_line_number:
        stax    line_buffer+Line::number
        jsr     skip_whitespace         ; Detect a blank line; returns non-blank character in A, may be zero
        tax                             ; Transfer into X to check if it's zero
        beq     @blank_line
        ldax    #statement_name_table
        jsr     parse_element           ; Leaves the parsed statement in line_buffer and sets/clears carry
        bcs     @done                   ; Parse failed
@blank_line:
        mva     lp, line_buffer+Line::next_line_offset  ; Write position is next statement offset
        ldx     bp
        lda     buffer,x                ; Verify the line ends as expected
        clc
        beq     @done                   ; If so then jump to done with carry still clear
        sec                             ; Otherwise set carry to indicate failure
@done:
        rts

; Parses and tokenizes a syntax element starting with a name.
; The last byte of buffer should be 0, which won't match anything. This avoids the need to keep checking
; the buffer length.
; AX = pointer to the first entry of the name table
; Returns carry clear if the input matched a rule, or carry set if it didn't match any syntax rule.

parse_element:
        jsr     find_name               ; Start by finding name; sets np and returns index in A
        bcs     @error
        jsr     encode_byte             ; Encode index
@loop:
        jsr     skip_whitespace         ; Skip whitespace after a character sequence or a directive
        ldy     np                      ; Get the character at np-1
        dey
        lda     (name_ptr),y
        bmi     @success                ; If the high bit was set, then it was the last byte; success
        iny                             ; Advance to current position
        lda     (name_ptr),y            ; Get next charater from name table entry
        tay                             ; Store it in Y so we can use it for several checks
        and     #$60                    ; Check if it's a directive (not a literal, x00x xxxx)
        beq     @directive              ; It is
        jsr     match_character_sequence    ; Otherwise it's a literal character sequence; match it
        bcc     @loop                   ; Continue after a character sequence match
@error:
        rts                             ; Return with carry set to indicate error

@success:
        clc                             ; Signal success
        rts  

@directive:
        inc     np                      ; Move position past directive
        tya
        and     #$7F                    ; Clear the high bit if it's set
        jsr     parse_directive
        bcc     @loop
        bcs     @error

parse_argument_type_vectors:
        .word   parse_variable          ; NT_VAR
        .word   parse_repeated_variable ; NT_RPT_VAR

; Parses a single directive.
; Since parsing the directive can recursively invoke the name table element parser with new values for name_ptr etc.,
; save the current values to the stack first. The parsers invoked after this point should NOT use these values.
; A = the directive
; TODO: make sure there's enough room on the stack; detect parses that recurse too deeply.

; Make sure NT_VAR is the first typed directive
.assert NT_VAR = $10, error

parse_directive:
        tay                             ; Keep in Y while using A to save state
        ldphaa  name_ptr                ; Save state in case of recursive call
        ldpha   np
        ldpha   argument_count
        tya                             ; Recover directive from Y
        sec
        sbc     #NT_VAR                 ; If we can subtract NT_VAR without borrowing then it's a single-arg directive
        bcs     @single
        and     #$0F                    ; Mask out top 4 bits
        jsr     parse_argument_list
        jmp     @pop

@single:
        tay                             ; The value left in A after subtracting NT_VAR is the vector index
        ldax    #parse_argument_type_vectors
        jsr     invoke_indexed_vector   ; Jump to the parser for the argument type
@pop:
        plsta   argument_count
        plsta   np
        plstaa  name_ptr                ; Recover variables from stack
        rts

; Parses an argument list of N expressions delimited by commas.
; All expressions are optional; if we find less than N expressions, encode TOKEN_NO_VALUE up to N.
; A = the number of arguments (must be >= 1)

parse_argument_list:
        and     #$07                    ; Bottom 3 bits are number of arguments to read (>0)
        sta     argument_count
@next:
        jsr     parse_expression        ; Parse the argument expression
        bcs     @parse_failed
@value:
        dec     argument_count          ; One argument done
        beq     @success                ; All done parsing arguments
        jsr     parse_argument_separator    ; Look for argument separator
        bcs     @next                   ; Found separator so continue parsing

; Fall through; argument_count must be >= 1 since we didn't go to @success.

@parse_failed:
        lda     #TOKEN_NO_VALUE         ; Store "no value" tokens for any remaining arguments
        jsr     encode_byte             ; Encode the "no value" token
        bcs     @error                  ; encode_byte error
        dec     argument_count          ; Done with one "no value"
        bne     @parse_failed           ; Loop if more
@success:
        clc                             ; Signal no error
@error:
        rts

; Parses and tokenizes a expression.

parse_expression:
        jsr     parse_number
        bcc     @done
        jsr     parse_variable
@done:
        rts

; Parses a number from the buffer.

parse_number:
        jsr     read_number
        bcs     @done
        jsr     encode_number           ; Will set carry if fail
@done:
        rts

; Parses a variable name.
; Tries to match the current buffer at position bp with the names in the variable name table.
; If the name is not found, then extends the variable name table.

parse_variable:
        jsr     skip_whitespace         ; Leaves next character in A
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

; Parses a series of variable names separated by commas.

parse_repeated_variable:
        jsr     parse_variable          ; Parse 1 variable
        bcs     @done                   ; It's always an error if we expected a variable and didn't find one
        jsr     parse_argument_separator    ; Try to read a separator
        bcs     parse_repeated_variable ; If carry set keep going; if carry clear then no separator and we're done
        jsr     encode_no_value         ; Terminate the repeated list
@done:
        rts

; Parses a mandatory comma beween arguments. Does not write any tokens.
; Return codes are reversed: we return carry clear if we did *not* find a separator and carry set if we did.
; Y SAFE

parse_argument_separator:
        jsr     skip_whitespace         ; Leaves next character in A
        cmp     #','                    ; Sets carry if character was ','
        bne     @error
        inc     bp
        rts

@error:
        clc                             ; Clear carry since we don't know its state following the CMP above
        rts

; Skip past any whitespace in the buffer. Returns the next character in A. The final value of bp is also left in X.
; bp = the read position (modified)
; Y SAFE, BC SAFE, DE SAFE

skip_whitespace:
        ldx     bp                      ; Use X to index buffer
@next:      
        lda     buffer,x        
        inx     
        cmp     #' '        
        beq     @next       
        dex                             ; It wasn't whitespace so go back
        stx     bp                      ; Update read position
        rts
