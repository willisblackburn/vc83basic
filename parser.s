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

; Parses a complete statement, either at the start of a line, or after THEN.
; The last byte the statement should be 0, which won't match anything. This avoids the need to keep checking
; the buffer length.
; AX = pointer to the first entry of the name table
; Returns carry clear if buffer was a valid statement, or carry set if it was not.

parse_statement:
        jsr     parse_name
        bcs     @error
        ldax    #statement_name_table
        jsr     find_name               ; Start by finding name; sets name_pos and returns index in A
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
        ldx     buffer_pos              ; Otherwise comapre it to the current character in the buffer
        cmp     buffer,x
        bne     @error
        inc     name_pos                ; Go to next character
        inc     buffer_pos
        bne     @next_character
        
@directive:
        inc     name_pos                ; Move position past directive
        tya
        jsr     parse_directive
        bcc     @after_directive

@success:
        clc                             ; Signal success
        rts

@error:
        sec
        rts  

parse_argument_type_vectors:
        .word   parse_variable-1            ; NT_VAR

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
        ldpha   name_pos
        tya                             ; Recover directive from Y
        sec
        sbc     #NT_VAR                 ; If we can subtract NT_VAR without borrowing then it's a single-arg directive
        bcs     @single
        jsr     parse_expression        ; Just parse one expression for now
        jmp     @pop

@single:
        tay                             ; The value left in A after subtracting NT_VAR is the vector index
        ldax    #parse_argument_type_vectors
        jsr     invoke_indexed_vector   ; Jump to the parser for the argument type
@pop:
        plsta   name_pos
        plstaa  name_ptr                ; Recover variables from stack
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
        jsr     skip_whitespace
        jsr     read_number
        bcs     @done
        jsr     encode_number           ; Will set carry if fail
@done:
        rts

; Parses a variable name.
; Tries to match the current buffer at position buffer_pos with the names in the variable name table.
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

; Parses a name from buffer, starting at buffer_pos.
; Sets name_start_pos.
; Returns carry clear if there was a name at buffer_pos, or carry set if the character at buffer_pos doesn't start a name.
; Y SAFE, BC SAFE, DE SAFE

parse_name:
        jsr     skip_whitespace
        stx     name_start_pos          ; If there is a name, it starts here
        jsr     is_name_character       ; Check for initial name character
        bcs     @done
@next_character:
        inx                             ; Next character
        lda     buffer,x                ; Check next character
        jsr     is_name_character       ; Is it a name character?
        bcc     @next_character         ; Yes, keep going
        stx     buffer_pos              ; Update buffer_pos
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

; Skip past any whitespace in the buffer. Returns the next character in A. The final value of buffer_pos is also left in X.
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
