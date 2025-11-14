.include "macros.inc"
.include "basic.inc"

; All "parse" functions use:
; buffer = the buffer containing the user-entered program source
; buffer_pos = the read position in buffer (modified on success)
; line_buffer = the buffer containing the tokenized output
; line_pos = the token write position in line_buffer (modified on success)

; Parses a line from the buffer. The line is an optional line number followed by statements.
; If the line number is missing, set it to -1.
; Returns normally if buffer was a valid program line, or raises an exception.

parse_line:
        mva     #0, buffer_pos              ; Initialize the read pointer
        mva     #.sizeof(Line), line_pos    ; Initialize write pointer
        jsr     skip_whitespace
        ldax    #buffer                 ; Read line number from buffer
        ldy     buffer_pos
        jsr     string_to_fp            ; Parse line number
        sty     buffer_pos              ; Initialize buffer_pos to wherever the number ended
        bcs     @no_line_number         ; Line number was provided so store it
        jsr     truncate_fp_to_int      ; Truncate line number to integer
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
        jsr     new_parse_statement     ; Leaves the parsed statement in line_buffer and sets/clears carry
        lda     line_pos                ; Write position is next statement offset
        ldx     statement_line_pos      ; Store at start of statement
        sta     line_buffer,x
        jsr     parse_statement_separator
        bcs     @next_statement
@blank_line:
        mva     line_pos, line_buffer+Line::next_line_offset    ; Write position is next line offset
        ldx     buffer_pos
        lda     buffer,x                ; Verify the line ends with 0 as expected
        bne     syntax_error            ; Nope, fail
        rts

; Parses a complete statement.
; The last byte of the statement should be 0, which won't match anything. This avoids the need to keep checking
; the buffer length.
; Returns normally if buffer was a valid statement, or raises an exception.

parse_statement:
        ldax    #statement_name_table
        jsr     initialize_name_ptr
@next:
        jsr     parse_next_statement    ; Will restore parser state on failure
        bcs     @next                   ; Failed; try again; will raise exception if we run out of names
        rts                             ; Will either return here with carry clear or raise exception

; Try to parse the buffer starting with the name table entry at name_ptr.

parse_next_statement:
        jsr     save_parser_state
        jsr     parse_tokenized_name_2
        bcs     syntax_error            ; Fail: either can't parse a name or can't find it in name table at all
        jsr     encode_byte             ; Encode statement token
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
        bne     @error

@directive:
        jsr     rebase_name_ptr         ; Catch up name_ptr
        txa                             ; Recover the directive
        tay                             ; Move into Y in order to use A to save name state
        phzp    NAME_STATE, NAME_STATE_SIZE
        tya                             ; Recover directive from Y
        jsr     parse_directive
        tay                             ; Save return value while clearing stack
        plzp    NAME_STATE, NAME_STATE_SIZE
        bcs     @error                  ; If parse_directive failed
        tya                             ; Recover return value
        jsr     encode_zero             ; Terminate with 0
        jmp     @after_directive

@error:
        sec                             ; Tell save_parser_state epilogue to restore state
        rts

@success:
        clc                             ; Tell save_parser_state to discard state
        rts

syntax_error:
        raise ERR_SYNTAX_ERROR

parse_argument_type_vectors:
        .word   parse_variable-1            ; NT_VAR
        .word   parse_repeated_variable-1   ; NT_RPT_VAR
        .word   parse_number-1              ; NT_NUMBER
        .word   parse_repeated_number-1     ; NT_RPT_NUMBER
        .word   parse_statement-1           ; NT_STATEMENT
        .word   parse_print_expression-1    ; NT_PRINT_EXP
        .word   parse_text-1                ; NT_TEXT

; Parses a single directive.
; Since parsing the directive can recursively invoke the parser with new values for name_ptr etc.,
; save the current values to the stack first. The parsers invoked after this point should NOT use these values.
; A = the directive
; TODO: make sure there's enough room on the stack; detect parses that recurse too deeply.

; Make sure NT_VAR is the first typed directive
.assert NT_VAR = $10, error

parse_directive:
        tay                             ; Retain directive in A
        sec
        sbc     #NT_VAR                 ; If we can subtract NT_VAR without borrowing then it's a single-arg directive
        bcs     @single
        tya                             ; Pass in expected number of arguments
        jsr     parse_argument_list
        bcs     @done                   ; Error parsing arguments
        bpl     @done                   ; Parsed all or some arguments; too few are okay
        sec                             ; Parsed too many arguments; fail
@done:
        rts

@single:
        tay                             ; The value left in A after subtracting NT_VAR is the vector index
        ldax    #parse_argument_type_vectors
        jmp     invoke_indexed_vector   ; Jump to the parser for the argument type

parse_variable:
        jsr     save_parser_state
        jsr     parse_name              ; Parse the variable name
        bcs     @done
        cpy     #<(name_pattern_op - name_pattern)  ; Make sure it was a name not an operator
        bcs     @done                   ; Was an operator
        ldx     buffer_pos              ; Check the next character to see if this is an array
        lda     buffer,x
        cmp     #'('                    ; Is this an array?
        clc                             ; If not we're going to return with carry clear
        bne     @done
        inc     buffer_pos              ; Skip past it
        jsr     encode_byte             ; Encode the '('
        jsr     parse_argument_list     ; Parse the array arguments; A will still be '(' but we don't care
        bcs     @done
        jsr     parse_close             ; Parse the closing parenthesis and return result
@done:
        rts                             ; CPY sets carry correctly for return

; Parses a series of names separated by commas.

parse_repeated_variable:
        jsr     parse_variable          ; Parse next variable name
        bcs     @done                   ; It's always an error if we expected a variable and didn't find one
        jsr     parse_argument_separator    ; Try to read a separator
        bcs     parse_repeated_variable ; If carry set keep going; if carry clear then no separator and we're done

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
        jsr     parse_argument_separator    ; Try to read a separator
        bcc     @done                   ; No separator; return
        jsr     parse_expression        ; Parse the argument following the separator
        bcc     @next                   ; Failing to parse an argument just means we reached the end
@done:
        pla                             ; Return modified argument count in A; sets flags
        rts                             ; Accurately returns carry set on failure, clear on success

; Parses a print expression, which is like an argument list except that we recognize both ',' and ';'
; as separators.

parse_print_expression:
        jsr     parse_print_separators  ; Don't care how many initial separators we find
@next_expression:
        jsr     parse_expression        ; Parse one expresion
        bcs     @done                   ; No expression when we expected to find one, so we're done
        jsr     parse_print_separators  ; Look for more sepearators
        bne     @next_expression        ; If there seperators then OK to parse another expression
@done:
        clc
        rts

; Parse a series of print separators.

parse_print_separators:
        ldy     line_pos                ; Remember starting position
@next_separator:
        jsr     skip_whitespace
        cmp     #';'                    ; Is it a semicolon?
        beq     @encode
        cmp     #','                    ; Is it a comma?
        beq     @encode
        cpy     line_pos                ; Sets zero flag if we're still at the starting position
        rts

@encode:
        jsr     encode_byte
        inc     buffer_pos
        bne     @next_separator

; Parses free-form text until the end of the line.

parse_text:
        ldy     #<(text_pattern - name_pattern - 3)
        jmp     parse_pattern

; Parses and tokenizes a expression.

parse_expression:
        jsr     parse_primary_expression    ; Parse an expression without any binary operators
        bcs     @error                  ; Not found; must be an error
        jsr     parse_operator
        bcc     parse_expression        ; Binary operator found; keep parsing
        clc                             ; Success
@error:
        rts

; Parses a primary expression, that is, an expression that does not contain any binary operators.

parse_primary_expression:
        jsr     parse_parentheses       ; Look for an expression in parentheses
        bcc     @done
        jsr     parse_number
        bcc     @done
        jsr     parse_string
        bcc     @done
        jsr     parse_unary_operator
        bcc     @done
        jsr     parse_function          ; Try to parse a function invocation
        bcc     @done
        jsr     parse_variable          ; Try to parse a variable name
@done:
        rts

; Parses a binary operator. Only called from parse_expression.

parse_operator:
        jsr     save_parser_state
        ldax    #operator_name_table
        jsr     parse_tokenized_name
        bcs     @error
        ora     #TOKEN_OP               ; OR in the operator token
        jmp     encode_byte
@error:
        rts

; Parses an expression in parentheses.

parse_parentheses:
        jsr     save_parser_state
        jsr     skip_whitespace         ; Skip whitespace and return the next character
        cmp     #'('                    ; Is is a left paren?
        sec                             ; Prepare to return error in case it's not
        bne     @done                   ; This is not an expression in parentheses
        jsr     encode_byte
        inc     buffer_pos              ; Skip over the left paren
        jsr     parse_expression        ; Parse the expression in the parentheses
        bcc     parse_close
@done:
        rts

parse_close:
        jsr     skip_whitespace         ; Find the next character, ...
        cmp     #')'                    ; which had better be a right parenthesis
        sec                             ; Set carry so if we take the next branch we return error
        bne     @done                   ; But it wasn't
        jsr     encode_byte             ; Store it
        inc     buffer_pos              ; Skip over the close paren
        clc                             ; Clear carry to indicate success
@done:
        rts
 
; Parses the unary operators '-' (minus) and NOT.

parse_unary_operator:
        jsr     save_parser_state
        ldax    #unary_operator_name_table
        jsr     parse_tokenized_name
        bcs     @error
        ora     #TOKEN_UNARY_OP         ; OR in the unary operator token
        jsr     encode_byte             ; Store the unary minus token
        jmp     parse_primary_expression    ; Continue and parse the following unary expression, which must exist
@error:
        rts

; Parses a function call.

parse_function:
        jsr     save_parser_state
        ldax    #function_name_table
        jsr     parse_tokenized_name
        bcs     @done
        ldx     buffer_pos              ; The next character must be a '(' w/o any whitespace
        ldy     buffer,x
        cpy     #'('
        sec                             ; Set carry in case next check fails
        bne     @done
        tay                             ; Save function number in Y
        ora     #TOKEN_FUNCTION         ; OR in the function token
        jsr     encode_byte             ; Store the token
        inc     buffer_pos              ; Skip '('
        lda     function_arity_table,y  ; Function number is in Y; look up how many arguments we need
        jsr     parse_argument_list
        sec                             ; Set carry in case next test fails
        beq     parse_close
@done:
        rts

; Parses a number from the buffer.

parse_number:
        ldy     #<(number_pattern - name_pattern - 3)
        jmp     parse_pattern

parse_repeated_number:
        jsr     parse_number            ; Parse a first number
        bcs     @done                   ; If no number then fail
        jsr     parse_argument_separator    ; Try to read a separator
        bcs     parse_repeated_number   ; Parse another number after the separator
@done:
        rts

parse_string:
        ldy     #<(string_pattern - name_pattern - 3)
        jmp     parse_pattern

name_pattern:
        .byte   'A', 26, <(name_pattern_identifier - name_pattern)
        .byte   '&', 10, <(name_pattern_op - name_pattern)
        .byte   '<',  3, <(name_pattern_relational - name_pattern)
        .byte   PATTERN_ERROR
name_pattern_identifier:
        .byte   'A', 26, <(name_pattern_identifier - name_pattern)
        .byte   '0', 10, <(name_pattern_identifier - name_pattern)
        .byte   '_',  1, <(name_pattern_identifier - name_pattern)
        .byte   '$',  1, <(name_pattern_string_suffix - name_pattern)
        .byte   PATTERN_OK
name_pattern_string_suffix:
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
string_pattern:
        .byte   '"',  1, <(string_pattern_2 - name_pattern)
        .byte   PATTERN_ERROR
string_pattern_2:
        .byte   '"',  1, <(string_pattern_3 - name_pattern)
        .byte   ' ', 96, <(string_pattern_2 - name_pattern)
        .byte   PATTERN_ERROR
string_pattern_3:
        .byte   '"',  1, <(string_pattern_2 - name_pattern)
        .byte   PATTERN_OK
text_pattern:
        .byte   ' ', 96, <(text_pattern - name_pattern)
        .byte   PATTERN_OK

; Parses a name from the buffer, using the state machine passed in AX, then looks up a name in the name table.
; AX = pointer to the start of the name table
; Returns carry clear on success with the index of the matched name in A. Returns carry set and restores buffer_pos
; on error.

parse_tokenized_name:
        jsr     initialize_name_ptr
parse_tokenized_name_2:
        jsr     parse_name              ; Go parse the name; decode_name_ptr set on return
        bcs     @error
        mva     decode_name_ptr, line_pos   ; Prepare to overwrite name in line_buffer (referenced by decode_name_ptr) with token
        jmp     find_name_2             ; Try to find the name in the name table

@error:
        rts

; Parses a name from the buffer.
; Sets the high bit on the last character in line_buffer, which is also returned (with the high bit set) in A.

parse_name:
        ldy     #<(name_pattern - name_pattern - 3)
        jsr     parse_pattern
        bcs     @error

; Set the EOT bit on most recently encoded byte.

        ldx     line_pos                ; Get line_buffer write position
        dex                             ; Back to last character we wrote
        lda     line_buffer,x
        ora     #EOT                    ; Set bit 7
        sta     line_buffer,x           ; Write back
@error:
        rts

; Fall through

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
        jsr     skip_whitespace
        mva     line_pos, decode_name_ptr           ; Initialize decode_name_ptr to the write position in line_buffer
        mva     #>line_buffer, decode_name_ptr+1    ; High byte of buffer address into decode_name_ptr
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
        bne     @match                  ; Unconditional

@terminal:
        ror     A                       ; Shift low bit from PATTERN_OK/ERROR into carry
        pla                             ; Pop saved value of buffer_pos off the stack
        bcc     @done
@error:
        sta     buffer_pos              ; Restore buffer_pos from stack
        mva     decode_name_ptr, line_pos   ; Restore line_pos to the value we saved earlier 
@done:
        rts

; Parses a mandatory colon beween arguments. Does not write any tokens.

parse_statement_separator:
        jsr     skip_whitespace
        cmp     #':'
        bne     separator_not_found
        inc     buffer_pos              ; Skip ':'
        rts                             ; Returns with carry set on equal

; Parses a mandatory comma beween arguments.
; Return codes are reversed: we return carry clear if we did *not* find a separator and carry set if we did. This is
; because often not finding the separator (carry clear) means that the parse has succeeded.
; Y SAFE

parse_argument_separator:
        jsr     skip_whitespace
        cmp     #','
        bne     separator_not_found
        inc     buffer_pos              ; Skip ','
        jsr     encode_byte             ; Leaves carry set on equal
        sec
        rts

separator_not_found:
        clc                             ; Means not found
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

; Save parser state on the stack.
; The parsing function should JSR to here. Calling this function will replace the caller's return address on the
; stack so that when the caller does RTS, control passes to the epilogue, which will restore the parser state if
; the carry flag is set.
; 
; Stack upon entry:     return address of caller's caller (2 bytes)
;                       return address of caller (2 bytes) (where RTS from this function goes)
;
; Modified stack:       return address of caller's caller
;                       parser state
;                       address of epilogue
;                       return address of caller (2 bytes) (where RTS from this function goes)

save_parser_state:
        stax    BC                      ; Arguments
        plstaa  DE                      ; Return address
        phzp    PARSER_STATE, PARSER_STATE_SIZE
        jsr     @continue_begin_parse   ; This JSR will return to begin_parse caller

; This is the epilogue that runs after the caller does RTS.
;
; Stack:                return address of caller's caller
;                       parser state

        stax    BC                      ; Return value
        bcc     @success
        plzp    PARSER_STATE, PARSER_STATE_SIZE
        bcs     @done                   ; Unconditional

@success:
        tsx                             ; Just add PARSER_STATE_SIZE to stack pointer to clear the stack
        txa
        adc     #PARSER_STATE_SIZE      ; Carry is already clear and this cannot set it
        tax
        txs
@done:
        ldax    BC
        rts

; By executing JSR to here, save_parser_state puts the address of the epilogue on the stack.
; Restore the original return address and also restore the arguments.

@continue_begin_parse:
        ldphaa  DE
        ldax    BC
        rts



new_parse_statement:
        ldax    #pvm_statement
        jsr     parse_pvm
        rts


; Invokes parsing virtual machine (PVM).
; CALL pushes a ParserState on the stack that can be retored with RETURN.
;   RETURN fails if the ParserState on the top of the stack did not come from CALL.
; CHOICE pushes a ParserState on the stack that will be restored with FAIL and discarded with COMMIT.
;   FAIL discards ParserStates created by CALL.
;   COMMIT fails if the ParserState on the top of the stack did not come from CHOICE.

parse_pvm:
        stax    pvm_program_ptr
        jsr     reset_stack_pointers    ; Parser uses the stack for backtracking
@next_instruction:
        ldy     #0
        lda     (pvm_program_ptr),y     ; Load PVM instruction
        sta     B                       ; Park in B
        iny                             ; Move past instruction

; Check for an address argument.

        and     #$04                    ; If bit 2 is set then an address argument follows
        beq     @argument               ; No address argument, check for match argument
        lda     (pvm_program_ptr),y
        sta     pvm_address_arg
        iny
        lda     (pvm_program_ptr),y
        sta     pvm_address_arg+1
        iny

; Look at the last three bits to figure out what arguments follow the instruction and load them.

@argument:
        lda     B
        and     #$03                    ; Mask off bottom two bits
        beq     @match                  ; If no argument then go on to match logic
        cmp     #$03                    ; Check if it's expecting a string
        beq     @string                 ; If so go do it, otherwise, A is the number of arguments
        sta     C                       ; C is the number of arguments to parse and is either 1 or 2
        sta     pvm_arg+1               ; If number of arguments is 1 this will leave pvm_arg+1 set to 1
        ldx     #0                      ; Reset X so we can use it to index pvm_arg
@next_argument:
        lda     (pvm_program_ptr),y     ; Get argument
        sta     pvm_arg,x               ; Save
        iny
        inx
        cpx     C
        bne     @next_argument
        beq     @match                  ; Unconditional

@string:
        jsr     rebase_pvm_program_ptr
        mvaa    pvm_program_ptr, pvm_arg    ; So we can save it into pvm_arg
        ldy     #$FF                    ; Now go looking for the character with bit 7 set that ends the string
@string_next:
        iny
        lda     (pvm_program_ptr),y
        bpl     @string_next     
        iny                             ; Skip the last one character and fall through to check address argument

; The arguments are parsed and Y points to the next PVM instruction.

@match:
        jsr     rebase_pvm_program_ptr  ; Catch up pvm_program_ptr to where Y is pointing to free up Y
        mvy     #0, C                   ; Now C is the match flag, default to false
        lda     B                       ; Recover the instruction from B
        bpl     @instruction            ; Not a matching instruction, so skip the matching logic
        mvx     buffer_pos, D           ; Definitely going to need this: store in D as beginning of match region
        and     #$03                    ; Get address type again
        beq     @match_any              ; Is a "match any" instruction, so don't need to match anything
        cmp     #$03                    ; Is it "match string?"
        beq     @match_string           ; Yep, go do it
        lda     buffer,x                ; It's "match char" or "match range;" get character from the buffer
        sec
        sbc     pvm_arg                 ; Check if it's in range
        bcc     @instruction
        cmp     pvm_arg+1
        bcs     @instruction
@match_any:
        inc     C                       ; Increment the match flag, making it true
        inx                             ; Move past the matched character
        bne     @instruction            ; Unconditional

@match_string:
        lda     (pvm_arg),y             ; Load the next value from the string to match
        bmi     @match_string_last      ; Handle the last character
        cmp     buffer,x                ; Otherwise compare with character in buffer
        bne     @instruction            ; No match
        iny                             ; Move to the next character
        inx
        bne     @match_string           ; Unconditional

@match_string_last:
        and     #$7F                    ; Clear the high bit
        cmp     buffer,x                ; Compare
        bne     @instruction            ; No match
        inc     C                       ; The whole string matched, so increment the match flag
        inx                             ; Skip over the last matched character

@instruction:
        lda     B                       ; Reload instruction again
        and     #$7F                    ; Clear high bit
        lsr     A                       ; Shift right to leave the instruction number in bits 0-3
        lsr     A
        lsr     A
        tay                             ; Instruction number into Y
        mvaa    #pvm_instruction_vectors, vector_table_ptr  ; Preserve X for handler
        jsr     invoke_indexed_vector_2 ; Invoke handler
        jmp     @next_instruction       ; No exception so continue

pvm_instruction_vectors:
        .word   ins_test-1
        .word   ins_match-1
        .word   ins_match_emit-1
        .word   ins_emit-1
        .word   ins_emit_byte-1
        .word   ins_choice-1
        .word   ins_commit-1
        .word   ins_begin_keyword-1
        .word   ins_tokenize_keyword-1
        .word   ins_jump_keyword-1
        .word   ins_compose-1
        .word   ins_jump-1
        .word   ins_call-1
        .word   ins_return-1
        .word   ins_fail-1

ins_test:
        lda     C                       ; Match?
        bne     ins_jump                ; Did match, so treat as JMP
        rts

ins_match:
        lda     C                       ; Match?
        beq     ins_fail                ; No match, treat as FAIL
        stx     buffer_pos              ; Consume the matched string
        rts

ins_match_emit:
        lda     C                       ; Just do same as ins_match
        beq     ins_fail                ; No match, treat as FAIL, else fall through to EMIT
        stx     buffer_pos              ; Consume the matched string

; Fall through

ins_emit:
        ldx     D                       ; Restore the beginning of the match
@emit_next:
        lda     buffer,x
        jsr     write_to_line_buffer
        inx
        cpx     buffer_pos              ; Caught up with read position?
        bne     @emit_next
        rts

ins_emit_byte:
        lda     pvm_arg

; Fall through

; Writes one byte to line_buffer.
; X SAFE

write_to_line_buffer:
        ldy     line_pos
        cpy     #MAX_LINE_LENGTH
        raieq   ERR_LINE_TOO_LONG
        sta     line_buffer,y
        inc     line_pos
        rts

ins_choice:
        lda     #.sizeof(ParserState)
        jsr     stack_alloc             ; Allocate space for the savepoint
        tax
        lda     buffer_pos
        sta     stack+ParserState::buffer_pos,x
        lda     line_pos
        sta     stack+ParserState::line_pos,x
        lda     pvm_address_arg
        sta     stack+ParserState::pvm_program_ptr,x
        lda     pvm_address_arg+1
        sta     stack+ParserState::pvm_program_ptr+1,x
        rts

ins_commit:
        ldx     stack_pos
        jsr     pop_parser_state
        raics   ERR_INTERNAL_ERROR      ; Parser state was from CALL

; Fall through

ins_jump:
        mvaa    pvm_address_arg, pvm_program_ptr
        rts

ins_fail:
        ldx     stack_pos               ; Check if stack is empty
        cpx     #PRIMARY_STACK_SIZE
        raieq   ERR_SYNTAX_ERROR        ; No CHOICE, so this FAIL fails the entire parse with syntax error
        jsr     pop_parser_state
        bcs     ins_fail                ; Parser state is from CALL; we should ignore
        lda     stack+ParserState::buffer_pos,x     ; Restore state from CHOICE
        sta     buffer_pos
        lda     stack+ParserState::line_pos,x
        sta     line_pos
        bcc     retore_pvm_program_ptr  ; Unconditional

ins_call:
        lda     #.sizeof(ParserState)
        jsr     stack_alloc             ; Allocate space to save the return address
        tax
        lda     #MAX_LINE_LENGTH        ; line_pos cannot be >= MAX_LINE_LENGTH so this indicates a CALL
        sta     stack+ParserState::line_pos,x
        lda     pvm_program_ptr
        sta     stack+ParserState::pvm_program_ptr,x
        lda     pvm_program_ptr+1
        sta     stack+ParserState::pvm_program_ptr+1,x
        mvaa    pvm_address_arg, pvm_program_ptr
        rts     

ins_return:
        ldx     stack_pos
        cpx     #PRIMARY_STACK_SIZE     ; If stack is empty then this RET from the top-level rule
        bne     return_from_call
        pla                             ; Pop the ins_return return value off the stack
        pla
        rts                             ; This breaks instruction-processing loop and returns from parse_pvm

return_from_call:
        jsr     pop_parser_state
        raicc   ERR_INTERNAL_ERROR      ; Parser state was from CHOICE

; Fall through

; Updates pvm_program_ptr from the ParserState saved on the stack.
; X = value of stack_pos

retore_pvm_program_ptr:
        lda     stack+ParserState::pvm_program_ptr,x    ; Return to the savepoint
        sta     pvm_program_ptr
        lda     stack+ParserState::pvm_program_ptr+1,x
        sta     pvm_program_ptr+1
        rts

; Pop the parser state from the stack and test line_pos vs. MAX_LINE_LENGTH:
; If this test returns with carry clear, then this parser state came from CHOICE, and if set, then from CALL.
; X = value of stack_pos

pop_parser_state:
        lda     #.sizeof(ParserState)   ; Pop the savepoint off the stack
        jsr     stack_free
        lda     stack+ParserState::line_pos,x
        cmp     #MAX_LINE_LENGTH        ; Return with carry clear (<MAX_LINE_LENGTH) or set (>=MAX_LINE_LENGTH)
        rts

ins_begin_keyword:
        mva     line_pos, decode_name_ptr           ; Set decode_name_ptr to start of name in line_buffer
        mvx     #>line_buffer, decode_name_ptr+1
        rts

ins_tokenize_keyword:
        lda     #EOT
        jsr     compose_with_last_byte
        ldax    pvm_address_arg
        jsr     find_name
        bcs     ins_fail                ; Didn't find the name; treat as FAIL
        ldx     decode_name_ptr
        sta     line_buffer,x           ; Write the token to line_buffer
        inx
        stx     line_pos                ; Reset line_pos to the space after teh token
        rts

ins_jump_keyword:
        mvaa    name_ptr, pvm_program_ptr
        rts

ins_compose:
        lda     pvm_arg
compose_with_last_byte:
        ldx     line_pos                ; Current line_pos
        ora     line_buffer-1,x         ; Subtract one since we want last character
        sta     line_buffer-1,x
        rts

; Rebases pvm_program_ptr by adding Y.
; pvm_program_ptr = pointer to current parse instruction
; Y = the offset to add to pvm_program_ptr
; X SAFE, Y SAFE, BC SAFE, DE SAFE

rebase_pvm_program_ptr:
        tya                             ; Move offset into A and add to pvm_program_ptr
        clc                             ; Not sure if carry is set or not so clear it now
        adc     pvm_program_ptr                 ; Add to pvm_program_ptr
        sta     pvm_program_ptr
        bcc     @done
        inc     pvm_program_ptr+1
@done:
        rts

; PVM macros

; Encodes string using .byte and sets bit 7 (EOT) on the last character.

.macro name s
    .local @length
    @length = .strlen(s)

    .if (@length > 0)
        ; Output all characters *except* the last one, if any.
        .if (@length > 1)
            .repeat @length - 1, i
                .byte   .strat(s, i)
            .endrep
        .endif
        
        ; Output the last character, bitwise OR'd with EOT
        .byte   .strat(s, @length - 1) | EOT
    .endif
.endmacro

.macro name_table_entry s
        .byte   :+ - *
        name s
.endmacro

.macro name_table_end
        .byte   0
.endmacro

.macro TEST m, address
    .if (.match(m, *))
        .byte   $84, <address, >address
    .elseif (.match(m, ""))
        .byte   $87
        .byte   <address, >address
        name m
    .else
        .byte   $85, <address, >address, m
    .endif
.endmacro

.macro TEST_RANGE m, n, address
    .byte   $86, <address, >address, m, n
.endmacro

.macro MATCH m
    .if (.match(m, *))
        .byte   $88
    .elseif (.match(m, ""))
        .byte   $8B
        name m
    .else
        .byte   $89, m
    .endif
.endmacro

.macro MATCH_RANGE m, n
    .byte   $8A, m, n
.endmacro

.macro MATCH_EMIT m
    .if (.match(m, *))
        .byte   $90
    .elseif (.match(m, ""))
        .byte   $93
        name m
    .else
        .byte   $91, m
    .endif
.endmacro

.macro MATCH_RANGE_EMIT m, n
    .byte   $92, m, n
.endmacro

.macro EMIT
        .byte   $18
.endmacro

.macro EMIT_BYTE b
        .byte   $21, b
.endmacro

.macro CHOICE address
        .byte   $2C, <address, >address
.endmacro

.macro COMMIT address
        .byte   $34, <address, >address
.endmacro

.macro JUMP address
        .byte   $5C, <address, >address
.endmacro

.macro CALL address
        .byte   $64, <address, >address
.endmacro

.macro RETURN
        .byte   $68
.endmacro

.macro BEGIN_KEYWORD
        .byte   $38
.endmacro

.macro TOKENIZE_KEYWORD address
        .byte   $44, <address, >address
.endmacro

.macro JUMP_KEYWORD
        .byte   $48
.endmacro

.macro COMPOSE b
        .byte   $51, b
.endmacro

.macro FAIL
        .byte   $70
.endmacro


; TEST	            1000 0100 aaaa
; TEST	            1000 0101 aaaa nn
; TEST	            1000 0110 aaaa bb ee
; TEST	            1000 0111 aaaa ccc
; MATCH	            1000 1000
; MATCH	            1000 1001 nn
; MATCH	            1000 1010 bb ee
; MATCH	            1000 1011 ccc
; MATCH_EMIT	    1001 0000
; MATCH_EMIT	    1001 0001 nn
; MATCH_EMIT	    1001 0010 bb ee
; MATCH_EMIT	    1001 0011 ccc
; EMIT	            0001 1000
; EMIT_BYTE	        0010 0001 nn
; CHOICE	        0010 1100 aaaa
; COMMIT	        0011 0100 aaaa
; BEGIN_KEYWORD	    0011 1000
; TOKENIZE_KEYWORD	0100 0100 aaaa
; JUMP_KEYWORD	    0100 1000
; COMPOSE           0101 0001 nn
; JUMP	            0101 1100 aaaa
; CALL	            0110 0100 aaaa
; RETURN	        0110 1000
; FAIL	            0111 0000
; WS etc.	        0111 1xxx


; PVM program

pvm_statement:
        CALL pvm_whitespace
        BEGIN_KEYWORD
        CALL pvm_name
        TOKENIZE_KEYWORD pvm_statement_name_table
        JUMP_KEYWORD

pvm_statement_name_table:
        name_table_entry "END"
            RETURN
:
        name_table_entry "RUN"
            RETURN
:
        name_table_entry "PRINT"
            JUMP pvm_expression
:
        name_table_entry "LET"
            CALL pvm_variable
            MATCH_EMIT '='
            JUMP pvm_expression
:
        name_table_entry "INPUT"
            JUMP pvm_variable_list
:
        name_table_entry "LIST"
            JUMP pvm_optional_arg_2
:
        name_table_entry "GOTO"
            JUMP pvm_number
:
        name_table_entry "GOSUB"
            JUMP pvm_number
:
        name_table_entry "RETURN"
            RETURN
:
        name_table_entry "POP"
            RETURN
:
        name_table_entry "ON"
            JUMP pvm_on
:
        name_table_entry "FOR"
            JUMP pvm_for
:
        name_table_entry "NEXT"
            JUMP pvm_variable
:
        name_table_entry "STOP"
            RETURN
:
        name_table_entry "CONT"
            RETURN
:
        name_table_entry "IF"
            JUMP pvm_if
:
        name_table_entry "NEW"
            RETURN
:
        name_table_entry "CLR"
            RETURN
:
        name_table_entry "DIM"
            JUMP pvm_variable
:
        name_table_entry "REM"
:
        name_table_entry "DATA"
:
        name_table_entry "READ"
            JUMP pvm_variable_list
:
        name_table_entry "RESTORE"
            JUMP pvm_number
:
        name_table_entry "POKE"
:
        name_table_end

keyword_name_table:
        name_table_entry "TO"
:
        name_table_entry "STEP"
:
        name_table_entry "GOTO"
:
        name_table_entry "GOSUB"
:
        name_table_entry "THEN"
:
        name_table_end

; Complex statements

pvm_on:
        CALL pvm_expression    
        CALL pvm_whitespace
        TEST "GO", @go
        FAIL
@go:
        CALL pvm_keyword
        JUMP pvm_number_list

pvm_for:
        CALL pvm_variable
        CALL pvm_whitespace
        MATCH_EMIT '='
        CALL pvm_expression
        CALL pvm_whitespace
        TEST "TO", @to
        FAIL
@to:
        CALL pvm_keyword
        CALL pvm_expression
        CALL pvm_whitespace
        TEST "STEP", @step
        RETURN
@step:
        CALL pvm_keyword
        JUMP pvm_expression

pvm_if:
        CALL pvm_expression
        CALL pvm_whitespace
        TEST "THEN", @then
        FAIL
@then:
        CALL pvm_keyword
        JUMP pvm_statement

; Argument lists

pvm_optional_arg_2:
        CHOICE @done
        CALL pvm_expression
        COMMIT @arg_2
@arg_2:
        CHOICE @done
        CALL pvm_whitespace
        MATCH_EMIT ','
        CALL pvm_expression
        COMMIT @done
@done:
        RETURN

; pvm_arg_list is list of 1-N expressions (but not 0).

pvm_arg_list:
        CALL pvm_expression
@next:
        CHOICE @done
        CALL pvm_whitespace
        MATCH_EMIT ','
        CALL pvm_expression
        COMMIT @next
@done:
        RETURN

; Expressions

pvm_expression:
        CALL pvm_primary_expression
        CHOICE @done
        CALL pvm_operator
        COMMIT pvm_expression
@done:
        RETURN

; pvm_primary_expression does not discard whitespace.
; The component that can be a primary expression discard whitespace.

pvm_primary_expression:
        CHOICE @string
        CALL pvm_whitespace
        MATCH_EMIT '('
        CALL pvm_expression
        CALL pvm_whitespace
        MATCH_EMIT ')'
        COMMIT @done
@string:
        CHOICE @number
        CALL pvm_string
        COMMIT @done
@number:
        CHOICE @function
        CALL pvm_number
        COMMIT @done
@function:
        CHOICE @variable
        CALL pvm_whitespace
        BEGIN_KEYWORD
        CALL pvm_name
        CHOICE @tokenize_function
        MATCH_EMIT '$'
        COMMIT @tokenize_function
@tokenize_function:
        TOKENIZE_KEYWORD function_name_table
        COMPOSE TOKEN_FUNCTION
        MATCH_EMIT '('
        CALL pvm_arg_list
        CALL pvm_whitespace
        MATCH_EMIT ')'
        COMMIT @done
@variable:
        CALL pvm_variable
@done:
        RETURN

; Low-level rules

pvm_number:
        CALL pvm_whitespace
        TEST '.', @initial_decimal
        CALL pvm_digits
        CHOICE @optional_e
        MATCH_EMIT '.'
        COMMIT @digits_after_decimal
@digits_after_decimal:
        CHOICE @optional_e
        CALL pvm_digits
        COMMIT @optional_e
@optional_e:
        CHOICE @done
        MATCH_EMIT 'E'
        CALL pvm_digits
        COMMIT @done
@initial_decimal:
        MATCH_EMIT *
        CHOICE @optional_e
        CALL pvm_digits
        COMMIT @optional_e
@done:
        RETURN

; pvm_digits does not remove whitespace.
; It is only used from pvm_number.

pvm_digits:
        MATCH_RANGE_EMIT '0', 10
@next:
        CHOICE @done
        MATCH_RANGE_EMIT '0', 10
        COMMIT @next
@done:
        RETURN


pvm_number_list:
        CALL pvm_number
@next:
        CHOICE @done
        CALL pvm_whitespace
        MATCH_EMIT ','
        CALL pvm_number
        COMMIT @next
@done:
        RETURN

pvm_string:
        CALL pvm_whitespace
        MATCH_EMIT '"'
@next:
        TEST '"', @first_quote
@second_quote:
        MATCH_EMIT *
        JUMP @next
@first_quote:
        MATCH_EMIT *
        TEST '"', @second_quote
        RETURN

pvm_variable:
        CALL pvm_whitespace
        CALL pvm_name
        CHOICE @eot
        MATCH_EMIT '$'
        COMMIT @eot
@eot:
        COMPOSE EOT
        TEST '(', @array
        RETURN
@array:
        MATCH_EMIT *
        CALL pvm_arg_list
        MATCH_EMIT ')'
        RETURN

pvm_variable_list:
        CALL pvm_variable
@next:
        CHOICE @done
        CALL pvm_whitespace
        MATCH_EMIT ','
        CALL pvm_variable
        COMMIT @next
@done:
        RETURN

pvm_operator:
        CALL pvm_whitespace
        BEGIN_KEYWORD
        MATCH_RANGE_EMIT ' ', 32
        CHOICE @end
        MATCH_RANGE_EMIT '<', 3
        COMMIT @end
@end:
        TOKENIZE_KEYWORD operator_name_table
        COMPOSE TOKEN_OP
        RETURN        

; pvm_keyword does not discard whitespace.
; Callers test for the correct keyword before calling and should discard whitespace at that point.

pvm_keyword:
        BEGIN_KEYWORD
        CALL pvm_name
        TOKENIZE_KEYWORD keyword_name_table
        COMPOSE TOKEN_KW
        RETURN

; pvm_name does not discard whitespace.
; Its only job is to capture an alphanumeric "name."

pvm_name:
        MATCH_RANGE_EMIT 'A', 26
@next:
        CHOICE @digit
        MATCH_RANGE_EMIT 'A', 26
        COMMIT @next
@digit:
        CHOICE @underscore
        MATCH_RANGE_EMIT '0', 10
        COMMIT @next
@underscore:
        CHOICE @done
        MATCH_EMIT '_'
        COMMIT @next        
@done:
        RETURN

pvm_whitespace:
        CHOICE @done
        MATCH ' '
        COMMIT pvm_whitespace
@done:
        RETURN

