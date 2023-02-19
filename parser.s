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

; Parses a line from the buffer. The line is an optional line number followed by statements.
; If the line number is missing, set it to -1.

parse_line:
        mva     #0, bp                  ; Initialize the read pointer
        mva     #Line::data, lp         ; Initialize write pointer
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
; The parse_next_element entry point parses a syntax element using the value already in name_ptr, not the one
; passed in AX.

parse_element:
        stax    name_ptr                ; Store initial name_ptr
        ldx     #0                      ; Starting name table index
parse_next_element:
        ldpha   bp                      ; Save bp value in case we have to backtrack
        ldpha   lp                      ; Same for lp value
        jsr     find_next_name          ; Start by finding name; sets np and returns index in A
        bcs     @no_match
        pha                             ; Store the return value
        jsr     encode_byte             ; Encode index
@loop:
        jsr     skip_whitespace         ; Skip whitespace after a character sequence or a directive
        jsr     read_name_table_byte    ; Read the next byte from the name table
        bcs     @success                ; If the high bit was set, then it was the last byte; success
        tay                             ; Store it in Y so we can use it again later
        and     #$60                    ; Check if it's a directive (not a literal, x00x xxxx)
        beq     @directive              ; It is
        jsr     match_character_sequence    ; Otherwise it's a literal character sequence; match it
        bcc     @loop                   ; Continue after a character sequence match
@backtrack_try_again:
        pla                             ; Return from find_next_name is starting index
        tax                             ; Transfer into X so we can pass it back to find_next_name
        plsta   lp                      ; Restore lp and bp
        plsta   bp
        jsr     advance_name_ptr        ; Advance past the failed name table entry (will preserve X)
        inx                             ; Increment X since we advanced name_ptr
        jmp     parse_next_element 

@success:
        clc                             ; Signal success
        pla                             ; Discard saved name entry index
@no_match:
        pla                             ; Discard saved lp and bp
        pla
        rts  

@directive:
        inc     np                      ; Move position past directive
        tya
        jsr     parse_directive
        bcc     @loop
        bcs     @backtrack_try_again

parse_argument_type_vectors:
        .word   parse_variable          ; NT_VAR
        .word   parse_repeated_variable ; NT_RPT_VAR
        .word   parse_number            ; NT_NUM
        .word   parse_repeated_number   ; NT_RPT_NUM
        .word   parse_statement         ; NT_STATEMENT

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
        ldax    #operator_name_table    ; Try to parse an operator from here
        jsr     find_name               ; Carry will be clear if one was found
        bcs     @no_operator            ; Not found; expression ends here
        jsr     encode_operator         ; The operator ID is in A; encode it
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
        jsr     find_name               ; See if it's one of the unary operators
        bcs     @done                   ; Nope
        jsr     encode_unary_operator   ; Store the unary minus token
        jmp     parse_primary_expression    ; Continue and parse the following unary expression, which must exist
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
        jmp     encode_variable       
@done:
        rts

; Parses a series of variable names separated by commas.

parse_repeated_variable:
        jsr     parse_variable          ; Parse 1 variable
        bcs     @done                   ; It's always an error if we expected a variable and didn't find one
        jsr     parse_argument_separator    ; Try to read a separator
        bcs     parse_repeated_variable ; If carry set keep going; if carry clear then no separator and we're done
        jmp     encode_no_value         ; Terminate the repeated list
@done:
        rts

; Parses the statement following THEN.

parse_statement:
        ldax    #statement_name_table
        jmp     parse_element

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

loop_skip_whitespace:
        inc     bp
skip_whitespace:
        ldx     bp                      ; Use X to index buffer
        lda     buffer,x        
        cmp     #' '        
        beq     loop_skip_whitespace       
        rts
