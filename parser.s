.include "macros.inc"
.include "basic.inc"

; All "parse" functions use:
; buffer = the buffer containing the user-entered program source
; buffer_pos = the read position in buffer (modified on success)
; line_buffer = the buffer containing the tokenized output
; line_pos = the token write position in line_buffer (modified on success)

; Reads a number from the buffer.
; If the first character is not a number, then return an error. Otherwise, read up to the first non-digit.
; buffer_pos = the read position in buffer
; Returns the number in AX, carry clear if ok, carry set if error

read_number:
        jsr     skip_whitespace         ; TODO: can check return here to see if it's a number
        ldy     buffer_pos              ; Use Y to index buffer (since AX will hold the number)
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
        cpy     buffer_pos              ; Did we parse anything?
        beq     @nothing                ; Nope
        sty     buffer_pos              ; Update read position
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
        mva     #0, buffer_pos          ; Initialize the read pointer
        mva     #Line::data, line_pos   ; Initialize write pointer
        jsr     read_number             ; Leaves line number in AX and buffer_pos points to next character in buffer
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
        jsr     parse_name
        bcs     @error
        mva     name_ptr, line_pos      ; name_ptr is pointing to name within line_buffer; back up line_pos to start
        ldax    #statement_name_table
        jsr     find_name               ; Start by finding name; sets record_ptr
        bcs     @error
        jsr     encode_byte             ; Replace name with statement token
@after_directive:
        jsr     skip_whitespace         ; Skip whitespace after the keyword and after a directive
@next:
        lda     record_ptr              ; Check low byte of current record_ptr
        cmp     next_record_ptr         ; Is it the next record_ptr?
        beq     @success                ; If so, have reached the end of the statement
        ldy     #0                      ; Get next byte from record_ptr
        lda     (record_ptr),y
        tax                             ; Temporarily store in X
        iny                             ; Move to next byte in name record
        jsr     rebase_record_ptr
        txa                             ; Restore byte from name record
        and     #$60                    ; Check if it's a directive (not a literal, x00x xxxx)
        beq     @directive              ; It is
        txa                             ; Name record byte again
        ldx     buffer_pos              ; Compare it to the current character in the buffer
        inc     buffer_pos              ; Increment buffer pointer
        cmp     buffer,x
        bne     @error
        beq     @next
        
@directive:
        txa                             ; Recover the directive
        jsr     parse_directive
        bcc     @after_directive

@success:
        clc                             ; Signal success
        rts

@error:
        sec
        rts  

parse_argument_type_vectors:
        .word   parse_name-1            ; NT_VAR
        .word   parse_repeated_name-1   ; NT_RPT_VAR

; Parses a single directive.
; Since parsing the directive can recursively invoke the parser with new values for record_ptr etc.,
; save the current values to the stack first. The parsers invoked after this point should NOT use these values.
; A = the directive
; TODO: make sure there's enough room on the stack; detect parses that recurse too deeply.

; Make sure NT_VAR is the first typed directive
.assert NT_VAR = $10, error

; Number of bytes of parser state to save, starting with record_ptr
PARSER_STATE_BYTES = 8

parse_directive:
        tay                             ; Keep in Y while using A to save state
        ldx     #(256 - PARSER_STATE_BYTES)     ; After PARSER_STATE_BYTES increments, X will wrap around to 0
@push_next:
        lda     record_ptr + PARSER_STATE_BYTES,x   ; Push the parser state
        pha                             ; First iteration, adding PARSER_STATE_BYTES + X = 256,
        inx                             ; wraps around to record_ptr
        bne     @push_next
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
        ldx     #PARSER_STATE_BYTES     ; Pop the parser state
@pop_next:
        pla
        dex                             ; Decrement to write index; sets Z flag it's zero
        sta     record_ptr,x
        bne     @pop_next
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
        jsr     parse_number
        bcc     @done
        jsr     parse_name
@done:
        rts

; Parses a number from the buffer.

parse_number:
        jsr     skip_whitespace
        jsr     read_number
        bcs     @done
        jsr     encode_number           ; Will set carry if fail
@done:
        rts

parse_name_rules:
        .byte   'A', 'Z' + 1, <(parse_name_rules_identifier - parse_name_rules)
        .byte   NAME_ERROR
parse_name_rules_identifier:
        .byte   'A', 'Z' + 1, <(parse_name_rules_identifier - parse_name_rules)
        .byte   '0', '9' + 1, <(parse_name_rules_identifier - parse_name_rules)
        .byte   '_', '_' + 1, <(parse_name_rules_identifier - parse_name_rules)
        .byte   NAME_OK

; Parses a name from buffer, starting at buffer_pos.
; Copies the name into line_buffer, sets the high bit on the last character, and sets name_ptr. 
; Returns carry clear if there was a name at buffer_pos.
; Returns carry set if the character at buffer_pos doesn't start a name. The state machine is set up so we only fail
; on the first character, in which case buffer_pos and line_pos will both be unchanged. After the first character, a
; non-name character just marks the end of the name.
; On return, Y will be left pointing to the rule that ended the parse, so a caller can check which rule it was.
; DE SAFE

; buffer must be page-aligned
.assert <buffer = 0, error

.assert NAME_OK = $80, error
.assert NAME_ERROR = $81, error

parse_name:
        mva     line_pos, name_ptr      ; Initialize name_ptr to the write position in line_buffer
        mva     #>line_buffer, name_ptr+1   ; High byte of buffer address into name_ptr
        jsr     skip_whitespace
        ldy     #$FD                    ; After three INY will start out with the first state
@skip:
        iny
        iny
        iny
@next_state:
        lda     parse_name_rules,y      ; Check the lower bound value to see if termination bit is set
        bmi     @terminate              ; We're done
        ldx     buffer_pos              ; Handle the character at buffer_pos
        lda     buffer,x                ; Next character
        cmp     parse_name_rules,y      ; Compare with lower bound
        bcc     @skip                   ; Character is < lower bound
        cmp     parse_name_rules+1,y    ; Compare with upper bound
        bcs     @skip                   ; Character is >= upper bound
        jsr     encode_byte             ; Encode the byte
        lda     parse_name_rules+2,y    ; Load next state
        tay                             ; Move into Y
        inc     buffer_pos              ; Next character; should always be >0
        bne     @next_state

@terminate:
        lsr     A                       ; Shift bit 0 into carry flag for return
        bcs     @done                   ; If we're going to fail then don't set the high bit on the last character   
        ldx     line_pos                ; Get line_buffer write position
        dex                             ; Back to last character we wrote
        lda     line_buffer,x
        eor     #NT_STOP                ; Set bit 7
        sta     line_buffer,x           ; Write back
@done:
        rts

; Parses a series of names separated by commas.

parse_repeated_name:
        jsr     parse_name              ; Parse next variable name
        bcs     @done                   ; It's always an error if we expected a variable and didn't find one
        jsr     parse_argument_separator    ; Try to read a separator
        bcs     parse_repeated_name     ; If carry set keep going; if carry clear then no separator and we're done
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
