
; All "parse" functions use:
; buffer = the buffer containing the user-entered program source
; buffer_pos = the read position in buffer (modified on success)
; line_buffer = the buffer containing the tokenized output
; line_pos = the token write position in line_buffer (modified on success)

; Parses a line from the buffer. The line is an optional line number followed by statements.
; If the line number is missing, set it to -1.

parse_line:
        mva     #0, buffer_pos              ; Initialize the read pointer
        mva     #.sizeof(Line), line_pos    ; Initialize write pointer
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
        mva     line_pos, line_buffer+Line::next_line_offset    ; Write position is next statement offset
        ldx     buffer_pos
        lda     buffer,x                ; Verify the line ends as expected
        clc
        beq     @done                   ; If so then jump to done with carry still clear
        sec                             ; Otherwise set carry to indicate failure
@done:
        rts

; Parses a complete statement.
; The last byte of the statement should be 0, which won't match anything. This avoids the need to keep checking
; the buffer length.
; Returns carry clear if buffer was a valid statement, or carry set if it was not.

parse_statement:
        jsr     parse_name
        bcs     @error
        mva     decode_name_ptr, line_pos   ; name_ptr is pointing to name in line_buffer; back up line_pos to start
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
        tay                             ; Move into Y in order to use A to save name state
        phzp    NAME_STATE, NAME_STATE_SIZE
        tya                             ; Recover directive from Y
        jsr     parse_directive
        jsr     encode_zero             ; Terminate with 0
        plzp    NAME_STATE, NAME_STATE_SIZE
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

parse_directive:
        sec
        sbc     #NT_VAR                 ; If we can subtract NT_VAR without borrowing then it's a single-arg directive
        bcs     @single
        jmp     parse_expression        ; Just parse one expression for now

@single:
        tay                             ; The value left in A after subtracting NT_VAR is the vector index
        ldax    #parse_argument_type_vectors
        jmp     invoke_indexed_vector   ; Jump to the parser for the argument type

; Parses and tokenizes a expression.

parse_expression:
        jsr     parse_number
        bcc     @done
        jsr     parse_name
@done:
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

; Parses a series of names separated by commas.

parse_repeated_name:
        jsr     parse_name              ; Parse next variable name
        bcs     @done                   ; It's always an error if we expected a variable and didn't find one
        jsr     parse_argument_separator    ; Try to read a separator
        bcs     parse_repeated_name     ; If carry set keep going; if carry clear then no separator and we're done
@done:
        rts

; Parses a number from the buffer.

parse_number:
        ldy     #<(number_pattern - name_pattern - 3)
        jmp     parse_pattern

name_pattern:
        .byte   'A', 26, <(name_pattern_identifier - name_pattern)
        .byte   PATTERN_ERROR
name_pattern_identifier:
        .byte   'A', 26, <(name_pattern_identifier - name_pattern)
        .byte   '0', 10, <(name_pattern_identifier - name_pattern)
        .byte   '_',  1, <(name_pattern_identifier - name_pattern)
        .byte   PATTERN_OK
number_pattern:
        .byte   '0', 10, <(number_pattern_2 - name_pattern)
        .byte   PATTERN_ERROR
number_pattern_2:
        .byte   '0', 10, <(number_pattern_2 - name_pattern)
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

; Parses a mandatory comma beween arguments.
; Return codes are reversed: we return carry clear if we did *not* find a separator and carry set if we did. This is
; because often not finding the separator (carry clear) means that the parse has succeeded.
; Y SAFE

parse_argument_separator:
        jsr     skip_whitespace
        cmp     #','
        bne     separator_not_found
        inc     buffer_pos              ; Skip ','
        jmp     encode_byte             ; Leaves carry set on equal

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
