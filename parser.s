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
        jsr     string_to_fp            ; Parse line number
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
        jsr     initialize_node_ptr
@try:
        ldpha   buffer_pos              ; Save the buffer position in case we need to backtrack
        ldpha   line_pos                ; And the line buffer position
        jsr     parse_tokenized_name_2
        bcs     @error
        jsr     encode_byte             ; Replace name with statement token
@after_directive:
        jsr     skip_whitespace         ; Skip whitespace after the keyword and after a directive
        ldy     #0                      ; Start reading from node_ptr offset 0
@next:
        tya                             ; Read position into A
        clc
        adc     node_ptr                ; Add to node_ptr; A is now low byte of read position
        cmp     next_node_ptr           ; Is it the next node_ptr?
        beq     @success                ; If so, have reached the end of the statement
        lda     (node_ptr),y
        iny                             ; Move to next byte in node data
        tax                             ; Temporarily store in X
        and     #$60                    ; Check if it's a directive (not a literal, x00x xxxx)
        beq     @directive              ; It is
        txa                             ; Restore byte from node data
        ldx     buffer_pos              ; Compare it to the current character in the buffer
        inc     buffer_pos              ; Increment buffer pointer
        cmp     buffer,x
        beq     @next
        bne     @backtrack_try_again

@directive:
        jsr     rebase_node_ptr         ; Catch up node_ptr
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
        .word   parse_statement-1           ; NT_STATEMENT

; Parses a single directive.
; Since parsing the directive can recursively invoke the parser with new values for node_ptr etc.,
; save the current values to the stack first. The parsers invoked after this point should NOT use these values.
; A = the directive
; TODO: make sure there's enough room on the stack; detect parses that recurse too deeply.

; Make sure NT_VAR is the first typed directive
.assert NT_VAR = $10, error

; Number of bytes of parser state to save, starting with node_ptr
PARSER_STATE_BYTES = 8

parse_directive:
        tay                             ; Keep in Y while using A to save state
        phzp    node_ptr, PARSER_STATE_BYTES
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
        plzp    node_ptr, PARSER_STATE_BYTES
        rts

parse_variable:
        jsr     parse_name              ; Parse the variable name
        cpy     #<(name_rules_op - name_rules)  ; Make sure it was a name not an operator
        rts                             ; CPY sets carry correctly for return

; Parses a series of names separated by commas.

parse_repeated_variable:
        jsr     parse_variable          ; Parse next variable name
        bcs     @done                   ; It's always an error if we expected a variable and didn't find one
        jsr     parse_argument_separator    ; Try to read a separator
        bcs     parse_repeated_variable ; If carry set keep going; if carry clear then no separator and we're done
        jsr     encode_no_value         ; Terminate the repeated list
@done:
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
        ldax    #operator_name_table
        jsr     parse_tokenized_name
        bcs     @no_operator            ; Not found; expression ends here
        ora     #TOKEN_OP               ; OR in the operator token
        jsr     encode_byte
        bcs     @error
        jmp     parse_expression        ; Otherwise parse the following expression

@no_operator:
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
        jsr     parse_name              ; Try to parse a variable name
@done:
        rts

; Parses an expression in parentheses.

parse_parentheses:
        jsr     skip_whitespace         ; Skip whitespace and return the next character
        cmp     #'('                    ; Is is a left paren?
        bne     @error                  ; This is not an expression in parentheses
        lda     #TOKEN_PAREN            ; Encode the paren
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

; Parses a number from the buffer.

parse_number:
        jsr     skip_whitespace
        jsr     string_to_fp            ; Parse the number
        bcs     @done
        jmp     encode_number           ; Will set carry if fail
@done:
        rts

parse_repeated_number:
        jsr     parse_number            ; Parse a first number
        bcs     @done                   ; If no number then fail
        jsr     parse_argument_separator
        bcs     parse_repeated_number   ; Parse another number after the separator
        jmp     encode_no_value         ; Terminate the repeated list
@done:
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
        jsr     initialize_node_ptr
parse_tokenized_name_2:
        ldpha   buffer_pos              ; Save buffer_pos value in case we have to return an error
        jsr     parse_name              ; Go parse the name; name_ptr set on return
        bcs     @error
        mva     name_ptr, line_pos      ; Prepare to overwrite name in line_buffer (referenced by name_ptr) with token
        jsr     find_name_2             ; Try to find the name in the name table
        bcs     @error                  ; Not valid
        tay                             ; Need A again
        pla                             ; Pop and discard the saved buffer_pos
        tya                             ; Recover A
        rts                             ; Return with carry clear        

@error:
        plsta   buffer_pos              ; Restore buffer_pos
        rts                             ; Return with carry set

name_rules:
        .byte   'A', 26, <(name_rules_identifier - name_rules)
        .byte   '&', 10, <(name_rules_op - name_rules)
        .byte   '<',  3, <(name_rules_relational - name_rules)
        .byte   NAME_ERROR
name_rules_identifier:
        .byte   'A', 26, <(name_rules_identifier - name_rules)
        .byte   '0', 10, <(name_rules_identifier - name_rules)
        .byte   '_',  1, <(name_rules_identifier - name_rules)
        .byte   NAME_OK
name_rules_op:
        .byte   NAME_OK
name_rules_relational:
        .byte   '<',  3, <(name_rules_relational - name_rules)
        .byte   NAME_OK

; Parses a name from buffer, starting at buffer_pos.
; Copies the name into line_buffer, sets the high bit on the last character, and sets name_ptr. 
; Returns carry clear if there was a name at buffer_pos.
; Returns carry set if the character at buffer_pos doesn't start a name. The state machine is set up so we only fail
; on the first character, in which case buffer_pos and line_pos will both be unchanged. After the first character, a
; non-name character just marks the end of the name.
; On return, Y will be left pointing to the rule that ended the parse, so a caller can check which rule it was.
; BC SAFE, DE SAFE

; buffer must be page-aligned
.assert <buffer = 0, error

.assert NAME_OK = $80, error
.assert NAME_ERROR = $81, error

parse_name:
        mva     line_pos, name_ptr      ; Initialize name_ptr to the write position in line_buffer
        mva     #>line_buffer, name_ptr+1   ; High byte of buffer address into name_ptr
        jsr     skip_whitespace
        ldy     #$FD                    ; Y=0 after three INY
@next_rule:
        iny                             ; Move to next state
        iny
        iny
@next_state:
        lda     name_rules,y            ; Check if first byte of rule has high bit set
        bmi     @terminal               ; If so then treat it like matching a terminal state
        ldx     buffer_pos              ; Handle the character at buffer_pos
        lda     buffer,x
        sec                             ; Set carry for subtract
        sbc     name_rules,y            ; Subtract lower bound
        cmp     name_rules+1,y          ; Compare with upper bound
        bcs     @next_rule              ; Character does not match this rule; continue
        lda     name_rules+2,y          ; Load next state
        bmi     @terminal
        tay                             ; Next state into Y
        lda     buffer,x
        jsr     encode_byte             ; Encode
        inc     buffer_pos              ; Next character; should always be >0
        bne     @next_state

@terminal:
        lsr     A                       ; Shift bit 0 into carry flag for return
        bcs     @done                   ; If we're going to fail then don't set the high bit on the last character   
        ldx     line_pos                ; Get line_buffer write position
        dex                             ; Back to last character we wrote
        lda     line_buffer,x
        ora     #NT_STOP                ; Set bit 7
        sta     line_buffer,x           ; Write back
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
