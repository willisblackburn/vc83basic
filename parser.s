.include "macros.inc"
.include "basic.inc"

; All "parse" functions use:
; buffer = the buffer containing the user-entered program source
; buffer_pos = the read position in buffer (modified on success)
; line_buffer = the buffer containing the tokenized output
; line_pos = the token write position in line_buffer (modified on success)

; Parses a line from the buffer. The line is an optional line number followed by statements.
; If the line number is missing, set it to -1.

parse_line:
        mva     #0, buffer_pos          ; Initialize the read pointer
        mva     #Line::data, line_pos   ; Initialize write pointer
        jsr     skip_whitespace
        ldax    #buffer                 ; Read line number from buffer
        ldy     buffer_pos
        jsr     read_number             ; Leaves line number in AX and buffer_pos points to next character in buffer
        sty     buffer_pos              ; Initialize buffer_pos to wherever the number ended
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
        mva     line_pos, line_buffer+Line::next_line_offset  ; Write position is next statement offset
        ldx     buffer_pos
        lda     buffer,x                ; Verify the line ends as expected
        clc
        beq     @done                   ; If so then jump to done with carry still clear
        sec                             ; Otherwise set carry to indicate failure
@done:
        rts

; Parses a complete statement.
; The last byte the statement should be 0, which won't match anything. This avoids the need to keep checking
; the buffer length.
; AX = pointer to the start of the name table
; Returns carry clear if buffer was a valid statement, or carry set if it was not.

parse_statement:
        ldax    #statement_name_table
        jsr     initialize_name_ptr
@try:
        ldpha   buffer_pos              ; Save the buffer position in case we need to backtrack
        ldpha   line_pos                ; And the line buffer position
        jsr     parse_tokenized_name_2
        bcs     @error
        jsr     encode_byte             ; Replace name with statement token
@after_directive:
        jsr     skip_whitespace         ; Skip whitespace after the keyword and after a directive
        ldy     #0                      ; Start reading from name_ptr offset 0
@next:
        tya                             ; Read position into A
        clc
        adc     name_ptr                ; Add to name_ptr; A is now low byte of read position
        cmp     next_name_ptr           ; Is it the next name_ptr?
        beq     @success                ; If so, have reached the end of the statement
        lda     (name_ptr),y
        iny                             ; Move to next byte in name table entry data
        tax                             ; Temporarily store in X
        and     #$60                    ; Check if it's a directive (not a literal, x00x xxxx)
        beq     @directive              ; It is
        txa                             ; Restore byte from name table entry data
        ldx     buffer_pos              ; Compare it to the current character in the buffer
        inc     buffer_pos              ; Increment buffer pointer
        cmp     buffer,x
        beq     @next
        bne     @backtrack_try_again

@directive:
        jsr     rebase_name_ptr         ; Catch up name_ptr
        txa                             ; Recover the directive
        jsr     parse_directive
        bcc     @after_directive

@backtrack_try_again:
        plsta   line_pos                ; Restore state
        plsta   buffer_pos
        jmp     @try

@success:
        clc                             ; Signal success
@error:
        pla                             ; Discard saved values
        pla
@done:
        rts  

parse_argument_type_vectors:
        .word   parse_variable-1            ; NT_VAR
        .word   parse_repeated_variable-1   ; NT_RPT_VAR
        .word   parse_number-1              ; NT_NUM
        .word   parse_repeated_number-1     ; NT_RPT_NUM

; Parses a single directive.
; Since parsing the directive can recursively invoke the parser with new values for name_ptr etc.,
; save the current values to the stack first. The parsers invoked after this point should NOT use these values.
; A = the directive
; TODO: make sure there's enough room on the stack; detect parses that recurse too deeply.

; Make sure NT_VAR is the first typed directive
.assert NT_VAR = $10, error

; Number of bytes of parser state to save, starting with name_ptr
PARSER_STATE_BYTES = 8

parse_directive:
        tay                             ; Keep in Y while using A to save state
        phzp    name_ptr, PARSER_STATE_BYTES
        tya                             ; Recover directive from Y
        sec
        sbc     #NT_VAR                 ; If we can subtract NT_VAR without borrowing then it's a single-arg directive
        bcs     @single
        tya                             ; Recover the directive again
        jsr     parse_argument_list
        jmp     @pop_parser_state

@single:
        tay                             ; The value left in A after subtracting NT_VAR is the vector index
        ldax    #parse_argument_type_vectors
        jsr     invoke_indexed_vector   ; Jump to the parser for the argument type

@pop_parser_state:
        plzp    name_ptr, PARSER_STATE_BYTES
        rts

parse_variable:
        jsr     parse_name              ; Parse the variable name
        cpy     #<(name_pattern_op - name_pattern)  ; Make sure it was a name not an operator
        rts                             ; CPY sets carry correctly for return

; Parses a series of names separated by commas.

parse_repeated_variable:
        jsr     parse_variable          ; Parse next variable name
        bcs     @done                   ; It's always an error if we expected a variable and didn't find one
        jsr     parse_argument_separator    ; Try to read a separator
        bcs     parse_repeated_variable ; If carry set keep going; if carry clear then no separator and we're done
        jsr     encode_zero             ; Terminate the repeated list
@done:
        rts

; Parses an argument list of N expressions delimited by commas.
; All expressions are optional; if we find less than N expressions, encode 0 up to N.
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
        jsr     encode_zero             ; Store 0 (no value) for any remaining arguments
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
        ldax    #operator_name_table
        jsr     parse_tokenized_name
        bcs     @no_operator            ; Not found; expression ends here
        ora     #TOKEN_OP               ; OR in the operator token
        jsr     encode_byte
        bcs     @error
        jmp     parse_expression        ; Otherwise parse the following expression

@no_operator:
        jsr     encode_zero             ; Terminate expression with 0
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
        jsr     parse_name              ; Try to parse a variable name
@done:
        rts

; Parses an expression in parentheses.

parse_parentheses:
        jsr     skip_whitespace         ; Skip whitespace and return the next character
        cmp     #'('                    ; Is is a left paren?
        bne     @error                  ; This is not an expression in parentheses
        jsr     encode_byte
        inc     buffer_pos              ; Skip over the left paren
        jsr     parse_expression        ; Parse the expression in the parentheses
        jsr     skip_whitespace         ; Find the next character, ...
        cmp     #')'                    ; which had better be a right parenthesis
        bne     @error                  ; But it wasn't
        inc     buffer_pos              ; Skip over the close paren
        clc                             ; Clear carry to indicate success
        rts
    
@error:
        sec                             ; Set carry to indicate error and return
        rts

; Parses the unary operators '-' (minus) and NOT.

parse_unary_operator:
        ldax    #unary_operator_name_table
        jsr     parse_tokenized_name
        bcs     @error
        ora     #TOKEN_UNARY_OP         ; OR in the unary operator token
        jsr     encode_byte             ; Store the unary minus token
        bcs     @error
        jmp     parse_primary_expression    ; Continue and parse the following unary expression, which must exist
@error:
        rts

; Parses a name from the buffer, using the state machine passed in AX, then looks up a name in the name table.
; AX = pointer to the start of the name table
; Returns carry clear on success with the index of the matched name in A. Returns carry set and restores buffer_pos
; on error.

parse_tokenized_name:
        jsr     initialize_name_ptr
parse_tokenized_name_2:
        ldpha   buffer_pos              ; Save buffer_pos value in case we have to return an error
        jsr     parse_name              ; Go parse the name; match_ptr set on return
        bcs     @error
        mva     match_ptr, line_pos     ; Prepare to overwrite name in line_buffer (referenced by match_ptr) with token
        jsr     find_name_2             ; Try to find the name in the name table
        bcs     @error                  ; Not valid
        tay                             ; Need A again
        pla                             ; Pop and discard the saved buffer_pos
        tya                             ; Recover A
        rts                             ; Return with carry clear        

@error:
        plsta   buffer_pos              ; Restore buffer_pos
        rts                             ; Return with carry set

; Parses a name from the buffer.
; Sets the high bit on the last character in line_buffer 

parse_name:
        ldy     #<(name_pattern - pattern_base - 3)
        jsr     parse_pattern
        bcs     @error                  ; Failed
        ldx     line_pos                ; Get line_buffer write position
        dex                             ; Back to last character we wrote
        lda     line_buffer,x
        ora     #NT_STOP                ; Set bit 7
        sta     line_buffer,x           ; Write back
@error:
        rts

; Parses a series of names separated by commas.

parse_repeated_name:
        jsr     parse_name              ; Parse next variable name
        bcs     @done                   ; It's always an error if we expected a variable and didn't find one
        jsr     parse_argument_separator    ; Try to read a separator
        bcs     parse_repeated_name     ; If carry set keep going; if carry clear then no separator and we're done
        jsr     encode_zero             ; Terminate the repeated list
@done:
        rts

; Parses a number from the buffer.

parse_number:
        ldy     #<(number_pattern - pattern_base - 3)
        jsr     parse_pattern
        bcs     @error
        jsr     encode_zero
@error:
        rts

parse_repeated_number:
        jsr     parse_number            ; Parse a first number
        bcs     @done                   ; If no number then fail
        jsr     parse_argument_separator
        bcs     parse_repeated_number   ; Parse another number after the separator
        jsr     encode_zero             ; Terminate the repeated list
@done:
        rts

pattern_base:
name_pattern:
        .byte   'A', 26, <(name_pattern_identifier - pattern_base)
        .byte   '&', 10, <(name_pattern_op - pattern_base)
        .byte   '<',  3, <(name_pattern_relational - pattern_base)
        .byte   PATTERN_ERROR
name_pattern_identifier:
        .byte   'A', 26, <(name_pattern_identifier - name_pattern)
        .byte   '0', 10, <(name_pattern_identifier - name_pattern)
        .byte   '_',  1, <(name_pattern_identifier - name_pattern)
        .byte   PATTERN_OK
name_pattern_op:
        .byte   PATTERN_OK
name_pattern_relational:
        .byte   '<',  3, <(name_pattern_relational - name_pattern)
        .byte   PATTERN_OK
number_pattern:
        .byte   '0', 10, <(number_pattern_2 - pattern_base)
        .byte   PATTERN_ERROR
number_pattern_2:
        .byte   '0', 10, <(number_pattern_2 - pattern_base)
        .byte   PATTERN_OK

; Parses characters from buffer that match a pattern, starting at buffer_pos.
; Copies the text into line_buffer and sets match_ptr. 
; Y = the starting state MINUS 3 (will be incremented by 3 prior to being used)
; Returns carry clear if there was a match at buffer_pos.
; Returns carry set if the character at buffer_pos didn't match.
; On return, Y will be left pointing to the state that ended the parse, so a caller can check which one it was.
; BC SAFE, DE SAFE

; buffer must be page-aligned
.assert <buffer = 0, error

parse_pattern:
        mva     line_pos, match_ptr     ; Initialize match_ptr to the write position in line_buffer
        mva     #>line_buffer, match_ptr+1  ; High byte of buffer address into match_ptr
        jsr     skip_whitespace
@next_state:
        iny                             ; Move to next state
        iny
        iny
@match:
        lda     name_pattern,y          ; Check if first byte has high bit set
        bmi     @terminal               ; If so then done
        ldx     buffer_pos              ; Handle the character at buffer_pos
        lda     buffer,x
        sec                             ; Set carry for subtract
        sbc     name_pattern,y          ; Subtract lower bound
        cmp     name_pattern+1,y        ; Compare with upper bound
        bcs     @next_state             ; Character does not match this state; continue
        lda     name_pattern+2,y        ; Load next state
        tay                             ; Next state into Y
        lda     buffer,x                ; Reload character from buffer
        jsr     encode_byte             ; Encode
        inc     buffer_pos              ; Next character; should always be >0
        bne     @match

@terminal:
        ror     A                       ; Shift low bit from PATTERN_OK/ERROR into carry
@done:
        rts

; Parses a mandatory comma beween arguments. Does not write any tokens.
; Return codes are reversed: we return carry clear if we did *not* find a separator and carry set if we did.
; Y SAFE

parse_argument_separator:
        jsr     skip_whitespace         ; Leaves next character in A
        cmp     #','                    ; Sets carry if character was ','
        bne     @error
        inc     buffer_pos
        rts

@error:
        clc                             ; Clear carry since we don't know its state following the CMP above
        rts

; Skip past any whitespace in the buffer. Returns the next character in A.
; The final value of buffer_pos is also left in X.
; buffer_pos = the read position (modified)
; Y SAFE, BC SAFE, DE SAFE

loop_skip_whitespace:
        inc     buffer_pos
skip_whitespace:
        ldx     buffer_pos              ; Use X to index buffer
        lda     buffer,x        
        cmp     #' '        
        beq     loop_skip_whitespace       
        rts
