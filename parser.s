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
        mva     match_ptr, line_pos     ; match_ptr is pointing to name within line_buffer; back up line_pos to start
        ldax    #statement_name_table
        jsr     find_name               ; Start by finding name; sets record_ptr
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
        bne     @error

@directive:
        jsr     rebase_name_ptr         ; Catch up name_ptr
        txa                             ; Recover the directive
        jsr     parse_directive
        bcc     @after_directive

@error:
        sec
        rts  

@success:
        clc                             ; Signal success
        rts

parse_argument_type_vectors:
        .word   parse_name-1            ; NT_VAR
        .word   parse_repeated_name-1   ; NT_RPT_VAR

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
        jsr     parse_expression        ; Just parse one expression for now
        jmp     @pop_parser_state

@single:
        tay                             ; The value left in A after subtracting NT_VAR is the vector index
        ldax    #parse_argument_type_vectors
        jsr     invoke_indexed_vector   ; Jump to the parser for the argument type

@pop_parser_state:
        plzp    name_ptr, PARSER_STATE_BYTES
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

name_pattern:
        .byte   'A', 26, <(name_pattern_identifier - name_pattern)
        .byte   NAME_ERROR
name_pattern_identifier:
        .byte   'A', 26, <(name_pattern_identifier - name_pattern)
        .byte   '0', 10, <(name_pattern_identifier - name_pattern)
        .byte   '_',  1, <(name_pattern_identifier - name_pattern)
        .byte   NAME_OK

; Parses characters from buffer that match a pattern, starting at buffer_pos.
; Copies the text into line_buffer, sets the high bit on the last character, and sets match_ptr. 
; Returns carry clear if there was a match at buffer_pos.
; Returns carry set if the character at buffer_pos didn't match. The patterns are set up so we only fail
; on the first character, in which case buffer_pos and line_pos will both be unchanged. After the first character, a
; non-matching character just marks the end of the match.
; On return, Y will be left pointing to the state that ended the parse, so a caller can check which one it was.
; BC SAFE, DE SAFE

; buffer must be page-aligned
.assert <buffer = 0, error

.assert NAME_OK = $80, error
.assert NAME_ERROR = $81, error

parse_name:
        mva     line_pos, match_ptr     ; Initialize match_ptr to the write position in line_buffer
        mva     #>line_buffer, match_ptr+1  ; High byte of buffer address into match_ptr
        jsr     skip_whitespace
        ldy     #$FD                    ; Y=0 after three INY
@next_state:
        iny                             ; Move to next state
        iny
        iny
@match:
        lda     name_pattern,y          ; Check if first byte has high bit set
        bmi     @terminal               ; If so then treat it like matching a terminal state
        ldx     buffer_pos              ; Handle the character at buffer_pos
        lda     buffer,x
        sec                             ; Set carry for subtract
        sbc     name_pattern,y          ; Subtract lower bound
        cmp     name_pattern+1,y        ; Compare with upper bound
        bcs     @next_state             ; Character does not match this state; continue
        lda     name_pattern+2,y        ; Load next state
        bmi     @terminal
        tay                             ; Next state into Y
        lda     buffer,x
        jsr     encode_byte             ; Encode
        inc     buffer_pos              ; Next character; should always be >0
        bne     @match

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
