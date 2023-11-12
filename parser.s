.include "macros.inc"
.include "basic.inc"

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
        jsr     parse_statement         ; Leaves the parsed statement in line_buffer and sets/clears carry
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

; Parses a complete statement, either at the start of a line, or after THEN.
; The last byte the statement should be 0, which won't match anything. This avoids the need to keep checking
; the buffer length.
; AX = pointer to the first entry of the name table
; Returns carry clear if buffer was a valid statement, or carry set if it was not.

parse_statement:
        jsr     parse_name
        bcs     @done
        ldax    #statement_name_table
        stax    name_ptr                ; Store initial name_ptr
        mva     #0, matched_name_index  ; Initialize name table index to 0
@next:
        ldpha   name_bp                 ; Save state in case we have to backtrack
        ldpha   bp
        ldpha   lp                      ; Same for lp value
        jsr     find_next_name          ; Start by finding name; sets np and returns index in A
        bcs     @error
        jsr     encode_byte             ; Encode index
@after_directive:
        jsr     skip_whitespace         ; Skip whitespace after the keyword and after a directive
@next_character:
        jsr     read_name_table_byte    ; Read the next byte from the name table
        bcs     @success                ; If the high bit was set, then it was the last byte; success
        tay                             ; Store it in Y so we can use it again later
        and     #$60                    ; Check if it's a directive (not a literal, x00x xxxx)
        beq     @directive              ; It is
        tya                             ; Get character back
        ldx     bp                      ; Otherwise comapre it to the current character in the buffer
        cmp     buffer,x
        bne     @backtrack_try_again
        inc     np                      ; Go to next character
        inc     bp
        bne     @next_character
        
@directive:
        inc     np                      ; Move position past directive
        tya
        jsr     parse_directive
        bcc     @after_directive

@backtrack_try_again:
        plsta   lp                      ; Restore state
        plsta   bp
        plsta   name_bp
        jsr     advance_name_ptr        ; Advance past the failed name table entry (will preserve X)
        inc     matched_name_index      ; Increment matched_name_index since we advanced name_ptr
        bne     @next                   ; Unconditional

@success:
        clc                             ; Signal success
@error:
        pla                             ; Discard saved values
        pla
        pla
@done:
        rts  

parse_argument_type_vectors:
        .word   parse_variable-1            ; NT_VAR
        .word   parse_repeated_variable-1   ; NT_RPT_VAR
        .word   parse_number-1              ; NT_NUM
        .word   parse_repeated_number-1     ; NT_RPT_NUM
        .word   parse_statement-1           ; NT_STATEMENT

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
        ldpha   matched_name_index
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
        plsta   matched_name_index
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
        jsr     encode_no_value         ; Store "no value" tokens for any remaining arguments
        bcs     @error                  ; encode_byte error
        dec     argument_count          ; Done with one "no value"
        bne     @parse_failed           ; Loop if more
@success:
        clc                             ; Signal no error
@error:
        rts

; Parses and tokenizes a expression.

parse_expression:
        jsr     parse_primary_expression    ; Parse an expression without any binary operators
        bcs     @error                  ; Not found; must be an error
        ldpha   bp                      ; Save bp in case I have to put back an unmatched name
        jsr     parse_operator_name     ; Check for an operator
        bcs     @no_operator
        ldax    #operator_name_table
        jsr     find_name               ; Carry will be clear if one was found
        bcs     @no_operator            ; Not found; expression ends here
        jsr     encode_operator         ; The operator ID is in A; encode it
        pla                             ; Pop and discard the saved bp value
        jmp     parse_expression        ; Otherwise parse the following expression

@no_operator:
        plsta   bp                      ; Retore the bp value
        jsr     encode_no_value         ; Terminate expression with TOKEN_NO_VALUE
        clc                             ; Signal success
@error:
        rts

; Parses a primary expression, that is, an expression that does not contain any binary operators.

parse_primary_expression:
        jsr     parse_parentheses       ; Look for an expression in parentheses
        bcc     @done
        jsr     parse_number
        bcc     @done
        jsr     parse_unary_operator
        bcc     @done
        jsr     parse_variable
@done:
        rts

; Parses an expression in parentheses.

parse_parentheses:
        jsr     skip_whitespace         ; Skip whitespace and return the next character
        cmp     #'('                    ; Is is a left paren?
        bne     @error                  ; This is not an expression in parentheses
        lda     #TOKEN_PAREN            ; Encode the paren
        jsr     encode_byte
        inc     bp                      ; Skip over the left paren
        jsr     parse_expression        ; Parse the expression in the parentheses
        jsr     skip_whitespace         ; Find the next character, ...
        cmp     #')'                    ; which had better be a right parenthesis
        bne     @error                  ; But it wasn't
        inc     bp                      ; Skip over the close paren
        clc                             ; Clear carry to indicate success
        rts
    
@error:
        sec                             ; Set carry to indicate error and return
        rts

; Parses a number from the buffer.

parse_number:
        jsr     skip_whitespace
        jsr     read_number
        bcs     @done
        jsr     encode_number           ; Will set carry if fail
@done:
        rts

parse_repeated_number:
        jsr     parse_number            ; Parse a first number
        bcs     @done                   ; If no number then fail
        jsr     parse_argument_separator
        bcs     parse_repeated_number   ; Parse another number after the separator
        jsr     encode_no_value         ; Terminate the repeated list
@done:
        rts

; Parses the unary operators '-' (minus) and NOT.

parse_unary_operator:
        ldpha   bp                      ; Save bp in case I have to put back an unmatched name
        jsr     parse_operator_name     ; Check for an operator
        bcs     @done
        ldax    #unary_operator_name_table
        jsr     find_name               ; See if it's one of the unary operators
        bcs     @done                   ; Nope
        jsr     encode_unary_operator   ; Store the unary minus token
        pla                             ; Pop the saved bp value and throw it away
        jmp     parse_primary_expression    ; Continue and parse the following unary expression, which must exist
@done:
        plsta   bp                      ; Restore bp
        rts

; Parses a variable name.
; Tries to match the current buffer at position bp with the names in the variable name table.
; If the name is not found, then extends the variable name table.

parse_variable:
        jsr     parse_name              ; Find a name
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

; Parses a name from buffer, starting at bp.
; Sets name_bp.
; Returns carry clear if there was a name at bp, or carry set if the character at bp doesn't start a name.
; Y SAFE, BC SAFE, DE SAFE

parse_name:
        jsr     skip_whitespace
        stx     name_bp                 ; If there is a name, it starts here
        jsr     is_name_character       ; Check for initial name character
        bcs     @done
@next_character:
        inx                             ; Next character
        lda     buffer,x                ; Check next character
        jsr     is_name_character       ; Is it a name character?
        bcc     @next_character         ; Yes, keep going
        stx     bp                      ; Update bp
        clc                             ; Signal success
@done:
        rts

; Checks if the character A is a name character. A name character is 'A'-'Z', '0'-'9', or '_'.
; Returns carry clear if it is, carry set if not.
; X SAFE, Y SAFE, BC SAFE, DE SAFE

is_name_character:
        cmp     #'_'                    ; Underbar is sepcial case
        clc                             ; Clear carry for return in case it was '_'
        beq     @done
        sec                             ; Prepare for subtract
        sbc     #'0'                    ; Check range 0-9
        cmp     #10                     ; Sets carry if char was >'9'
        bcc     @done                   ; It was in range 0-9
        sbc     #'A'-'0'                ; Check range 'A'-'Z'
        cmp     #26                     ; Sets carry if char was >'Z'
@done:      
        rts

; Parses an operator name.
; An operator is any of the single operator characters in the operator name table, or one of the relational
; operators, or one of the logic operators. Since the logical operators are names, we delegate to parse_name to
; identify them.

parse_operator_name:
        jsr     skip_whitespace
        stx     name_bp                 ; Operator name starts here
        ldy     #0                      ; Start at index 0 of all operator chars
        jsr     is_operator_name_character
        bcs     parse_name              ; If not then try parsing a name
        inx
        lda     buffer,x                ; Check the next position
        ldy     #2                      ; Start at index 2; ignore '+' and '-'
        jsr     is_operator_name_character
        bcs     @single                 ; Second character was not a match; bypass the increment of X
        inx                             ; The second character was also an operator character, so advance past it
@single:
        stx     bp                      ; Update bp
        clc                             ; Signal success
        rts        

; Checks if the character in A is an operator name character.
; The value of Y on entry determines which characters the function considers valid. If it is
; 0, then all characters in the operator name table will be considered, but if it greater, then the function will
; ignore the first Y operator characters. When Y=2, it will skip '+' and '-' in order to avoid considering those
; characters as the second character of an operator rather than separate unary operator.
; X SAFE, DE SAFE

is_operator_name_character:
        sta     B                       ; Store character in B
@next_operator:
        iny                             ; Pre-increment, so have to adjust Y down when using it 
        cpy     #<(operator_chars_end - operator_name_table + 1)    ; Check if we've reached the end of one-char names
        bne     @more                   ; No, check the next one
        rts                             ; Reached the end; since CPX was equal, carry is set to signal error

@more:
        lda     operator_chars-1,y      ; Check the next character
        and     #$7F                    ; Clear high bit
        cmp     B                       ; Is it B?
        bne     @next_operator
        clc                             ; Matched an operator character; signal success
        rts

; Skip past any whitespace in the buffer. Returns the next character in A. The final value of bp is also left in X.
; bp = the read position (modified)
; Y SAFE, BC SAFE, DE SAFE

loop_skip_whitespace:
        inc     bp
skip_whitespace:
        ldx     bp                      ; Use X to index buffer
        lda     buffer,x        
        cmp     #' '        
        beq     loop_skip_whitespace       
        rts
