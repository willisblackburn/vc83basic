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
        jsr     string_to_fp            ; Parse line number
        sty     buffer_pos              ; Initialize buffer_pos to wherever the number ended
        bcs     @no_line_number         ; Line number was provided so store it
        jsr     truncate_fp_to_int      ; Truncate line number to integer
        bcs     @done                   ; Out of range
        bcc     @store_line_number
@no_line_number:
        lda     #$FF                    ; Otherwise store -1 ($FFFF) instead
        tax
@store_line_number:
        stax    line_buffer+Line::number
        jsr     skip_whitespace         ; Detect a blank line; returns non-blank character in A, may be zero
        tax                             ; Transfer into X to check if it's zero
        beq     @blank_line

; Parse one statement. The statement must be found because the line is not blank and this is either the first
; statement or we just parsed a ':'.

@next_statement:
        mva     line_pos, statement_line_pos        ; Save start of statement position
        inc     line_pos                ; Begin tokenizing statement at next position
        jsr     parse_statement         ; Leaves the parsed statement in line_buffer and sets/clears carry
        bcs     @done                   ; Parse failed
        lda     line_pos                ; Write position is next statement offset
        ldx     statement_line_pos      ; Store at start of statement
        sta     line_buffer,x
        jsr     parse_statement_separator
        bcs     @next_statement
@blank_line:
        mva     line_pos, line_buffer+Line::next_line_offset    ; Write position is next line offset
        ldx     buffer_pos
        lda     buffer,x                ; Verify the line ends with 0 as expected
        clc
        beq     @done                   ; If so then jump to done with carry still clear
        sec                             ; Otherwise set carry to indicate failure
@done:
        rts

; Parses a complete statement.
; The last byte the statement should be 0, which won't match anything. This avoids the need to keep checking
; the buffer length.
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
        .word   parse_number-1              ; NT_NUMBER
        .word   parse_repeated_number-1     ; NT_RPT_NUMBER
        .word   parse_statement-1           ; NT_STATEMENT

; Parses a single directive.
; Since parsing the directive can recursively invoke the parser with new values for name_ptr etc.,
; save the current values to the stack first. The parsers invoked after this point should NOT use these values.
; A = the directive
; TODO: make sure there's enough room on the stack; detect parses that recurse too deeply.

; Make sure NT_VAR is the first typed directive
.assert NT_VAR = $10, error

parse_directive:
        tay                             ; Keep in Y while using A to save state
        phzp    PARSER_STATE, PARSER_STATE_SIZE
        tya                             ; Recover directive from Y
        sec
        sbc     #NT_VAR                 ; If we can subtract NT_VAR without borrowing then it's a single-arg directive
        bcs     @single
        tya                             ; Pass in expected number of arguments
        jsr     parse_argument_list
        bcs     @pop_parser_state       ; Error parsing arguments
        beq     @pop_parser_state       ; Parsed all arguments; carry must be clear here because BCS above
        sec                             ; If next condition met, return failure
        bmi     @pop_parser_state       ; Parsed too many arguments
        sta     B                       ; Store number of remaining arguments in B
@next_missing_argument:
        jsr     encode_zero             ; Store 0 (no value) for any remaining arguments
        bcs     @pop_parser_state       ; encode_byte error
        dec     B                       ; Done with one "no value"
        bne     @next_missing_argument  ; Loop if more
        beq     @pop_parser_state       ; Otherwise done; carry will be clear because BCS above

@single:
        tay                             ; The value left in A after subtracting NT_VAR is the vector index
        ldax    #parse_argument_type_vectors
        jsr     invoke_indexed_vector   ; Jump to the parser for the argument type

@pop_parser_state:
        plzp    PARSER_STATE, PARSER_STATE_SIZE
        rts

parse_variable:
        jsr     parse_name              ; Parse the variable name
        bcs     @done
        cpy     #<(name_pattern_op - name_pattern)  ; Make sure it was a name not an operator
@done:
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

; Parses a list of arguments separated by commas.
; Accepts the expected number of arguments in A and decrements for each argument, returning the result in A, which
; will be either negative if we parsed too many arguments, 0 if exactly the expected number, and positive if some
; arguments were missing.
; Zero-length argument lists are okay, but if we find a comma, there has to be a following argument.

parse_argument_list:
        pha                             ; Store the argument count that was passed in
        jsr     parse_expression        ; Parse the first argument
        bcc     @next                   ; Found one argument; continue
        clc                             ; Otherwise return success
        pla
        rts

@next:
        tsx                             ; Set up stack access
        dec     $101,x                  ; Decrement the argument count
        jsr     parse_argument_separator    ; Look for argument separator
        bcc     @done                   ; No separator; return
        jsr     parse_expression        ; Parse the argument following the separator
        bcc     @next                   ; Failing to parse an argument just means we reached the end
@done:
        pla                             ; Return modified argument count in A; sets flags
        rts                             ; Accurately returns carry set on failure, clear on success

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
        jsr     parse_variable          ; Try to parse a variable name
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
        jsr     parse_name              ; Go parse the name; decode_name_ptr set on return
        bcs     @error
        mva     decode_name_ptr, line_pos   ; Prepare to overwrite name in line_buffer (referenced by decode_name_ptr) with token
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
; Sets the high bit on the last character in line_buffer, which is also returned (with the high bit set) in A.

parse_name:
        ldy     #<(name_pattern - name_pattern - 3)
        jmp     parse_pattern

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
        ldy     #<(number_pattern - name_pattern - 3)
        jmp     parse_pattern

parse_repeated_number:
        jsr     parse_number            ; Parse a first number
        bcs     @done                   ; If no number then fail
        jsr     parse_argument_separator
        bcs     parse_repeated_number   ; Parse another number after the separator
        jsr     encode_zero             ; Terminate the repeated list
@done:
        rts

name_pattern:
        .byte   'A', 26, <(name_pattern_identifier - name_pattern)
        .byte   '&', 10, <(name_pattern_op - name_pattern)
        .byte   '<',  3, <(name_pattern_relational - name_pattern)
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
        .byte   '-',  1, <(number_pattern_2 - name_pattern)     ; Without following digit is a unary minus
number_pattern_2:
        .byte   '0', 10, <(number_pattern_3 - name_pattern)
        .byte   '.',  1, <(number_pattern_3 - name_pattern)
        .byte   PATTERN_ERROR
number_pattern_3:
        .byte   '0', 10, <(number_pattern_3 - name_pattern)
        .byte   '.',  1, <(number_pattern_3 - name_pattern)
        .byte   'E',  1, <(number_pattern_4 - name_pattern)
        .byte   PATTERN_OK
number_pattern_4:
        .byte   '-',  1, <(number_pattern_5 - name_pattern)     ; Not an operator if immediately after E
number_pattern_5:
        .byte   '0', 10, <(number_pattern_5 - name_pattern)
        .byte   PATTERN_OK

; Parses characters from buffer that match a pattern, starting at buffer_pos.
; Copies the text into line_buffer and sets decode_name_ptr. 
; Y = the starting state MINUS 3 (will be incremented by 3 prior to being used)
; Returns carry clear if there was a match at buffer_pos.
; Returns carry set if the character at buffer_pos didn't match.
; On return, Y will be left pointing to the state that ended the parse, so a caller can check which one it was.
; BC SAFE, DE SAFE

; buffer must be page-aligned
.assert <buffer = 0, error

parse_pattern:
        mva     line_pos, decode_name_ptr           ; Initialize decode_name_ptr to the write position in line_buffer
        mva     #>line_buffer, decode_name_ptr+1    ; High byte of buffer address into decode_name_ptr
        jsr     skip_whitespace
        ldpha   buffer_pos              ; Save buffer_pos so we can restore if error
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
        pla                             ; Pop saved value of buffer_pos off the stack
        bcs     @error

; Set the EOT bit on most recently encoded byte.

        ldx     line_pos                ; Get line_buffer write position
        dex                             ; Back to last character we wrote
        lda     line_buffer,x
        ora     #EOT                    ; Set bit 7
        sta     line_buffer,x           ; Write back
        rts

@error:
        sta     buffer_pos              ; Restore buffer_pos from stack
        mva     decode_name_ptr, line_pos   ; Restore line_pos to the value we saved earlier 
        rts

; Parses a mandatory colon beween arguments. Does not write any tokens.

parse_statement_separator:
        lda     #':'
        bne     parse_separator

; Parses a mandatory comma beween arguments. Does not write any tokens.

parse_argument_separator:
        lda     #','

; Parses a separator character.
; A = the separator character
; Return codes are reversed: we return carry clear if we did *not* find a separator and carry set if we did.
; Y SAFE

parse_separator:
        sta     B                       ; Use B for the comparison
        jsr     skip_whitespace
        cmp     B                       ; Compare non-whitespace character to separator
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
