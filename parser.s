.include "macros.inc"
.include "basic.inc"

.zeropage

directive: .res 1
argument_count: .res 1

.code

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
        jsr     skip_whitespace
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

argument_type_vectors:
        .word   parse_expression        ; NT_EXPRESSION
        .word   parse_number            ; NT_NUM
        .word   parse_variable          ; NT_VAR

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
; This function is called recursively. It sets up name_ptr and Y and saves them on the stack prior to calling
; other functions so that those functions can call back in to this one.
; AX = pointer to the first entry of the name table
; Returns carry clear if the input matched a rule, or carry set if it didn't match any syntax rule.

parse_element:

.assert NT_EXPRESSION = $10, error

; This whole first section uses Y to track the parse position in the name table entry pointed to by name_ptr.

        jsr     find_name               ; Sets Y to next byte in name table entry (AX passed to find_name)
        bcs     @error
        jsr     encode_byte             ; Encode the statement name
        bcs     @error                  ; encode_byte error

; Parse the next byte.
; First check the previous byte and see if the high bit was set; if so then end.
; Otherwise, determine if the current byte is:
; 1. A character -> match a sequence
; 2. An "N arguments" directive
; 3. A directive to parse one argument of a specific type
; Upon entry to this block, Y must point to the next character in the name table entry.

@next:
        sty     np                      ; Save name table entry position in np
        dey                             ; Back up 1
        lda     (name_ptr),y            ; Check for the end bit
        bmi     @success                ; Success if the end bit set
        iny                             ; Back to previous position
        lda     (name_ptr),y            ; Get the next byte
        tax                             ; Save in X since we're going to be checking it a lot
        and     #$60                    ; Figure out if this is a chracter sequence or a directive
        beq     @directive              ; It's a directive (x00x xxxx)
        jsr     match_character_sequence    ; Will advance Y past the matched sequence
        bcs     @error                  ; If not matched then error
        bcc     @next                   ; If matched then continue

; Handle arguments.

@directive:
        txa                             ; Get the original byte
        and     #$70                    ; Check if it's a multiple-argument directive (x000 xxxx)
        beq     @multiple               ; Yes
        txa                             ; Get the byte again
        and     #$0C                    ; Check if it's repeated (xxxx 11xx)
        cmp     #$0C
        beq     @repeated               ; Yes
        txa                             ; It's not multiple and not repeated, must be a single argument
        jsr     parse_argument
        jmp     @loop

@multiple:
        txa                             ; Get original byte
        jsr     parse_multiple_arguments
        jmp     @loop

@repeated:
        txa                             ; Get original byte
        jsr     parse_repeated_argument

@loop:
        bcs     @error
        inc     np                      ; Recover saved name table entry position
        ldy     np                      ; Advance 1
        bcc     @next

@success:
        clc

; We never jump to @error without carry being set so don't have to set it again.

@error:
        rts

; Parses arguments from the buffer and tokenizes them.
; Arguments must be separated by ','.
; In this function we don't pay attention to the name table anymore; we're only concerned with parsing some
; number of arguments.
; ARGUMENT COUNT MUST BE AT LEAST 1.
; A = the number of arguments to parse, from 1 to 7; bit 3 is true if these arguments are optional

parse_multiple_arguments:
        sta     directive
        and     #$07
        sta     argument_count
        lda     #NT_EXPRESSION
        jsr     parse_argument          ; Parse the argument value
        bcs     @parse_failed
@value:
        dec     argument_count          ; One argument done
        beq     @success                ; All done parsing arguments
        lda     #NT_EXPRESSION
        jsr     parse_following_argument    ; Parse the next argument value
        bcc     @value                  ; If separator parsed then continue with value, otherwise fail
@parse_failed:
        lda     directive               ; Get the original parse directive
        and     #NT_OPTIONAL            ; Mask the optional argument flag
        beq     @done                   ; Result was 0 so optional flag not set; fail
        ldy     argument_count          ; Optional was set so prepare to store "no value" tokens
@no_value:
        lda     #TOKEN_NO_VALUE
        jsr     encode_byte             ; Encode the "no value" token
        bcs     @done                   ; encode_byte error
        dey                             ; Done with one "no value"
        bne     @no_value               ; Loop if more
@success:
        clc                             ; Signal no error
@done:
        rts

; Parses a repeated value.
; A = the directive from the name table entry

.assert (NT_EXPRESSION & $0F) = (NT_RPT_EXPRESSION & $03), error
.assert (NT_NUM & $0F) = (NT_RPT_NUMBER & $03), error
.assert (NT_VAR & $0F) = (NT_RPT_VAR & $03), error

parse_repeated_argument:
        sta     directive
        and     #$03
        jsr     parse_argument
        bcs     @done
@next:
        lda     directive
        and     #$03
        jsr     parse_following_argument
        bcc     @next
@done:
        lda     #TOKEN_NO_VALUE
        jmp     encode_byte

; Parses a single argument.
; Since parsing the argument can recursively invoke the name table element parser with new values for name_ptr etc.,
; save the current values to the stack first. The parsers invoked after this point should NOT use these values.
; A = the type of argument to parse (as a name table directive)
; TODO: make sure there's enough room on the stack; detect parses that recurse too deeply.

parse_argument:
        and     #$0F                    ; Isolate just the type
        tay                             ; Prepare too use type as vector index
        ldphaa  name_ptr                ; Save name_ptr, np, and signature_ptr
        ldpha   np
        ldpha   directive
        ldax    #argument_type_vectors
        jsr     invoke_indexed_vector   ; Jump to the parser for the argument type
        plsta   directive
        plsta   np
        plstaa  name_ptr                ; Recover variables from stack
        rts

; Parses an argument separator followed by an argument.
; Reverts the read and write positions if parsing either the separator or argument fails.
; A = the type of argument to parse (as a name table directive)

parse_following_argument:
        tay                             ; Save the argument type directive
        jsr     parse_argument_separator
        bcs     @error
        tya                             ; Pass the argument type directive to parse_argument
        jsr     parse_argument
        bcs     @error
        rts

@error:
        rts

; Placeholder handler that just signals an error.

parse_error:
        sec
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
        jsr     read_number
        bcs     @done
        jsr     encode_number           ; Will set carry if fail
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
        jsr     encode_variable       
@done:
        rts

parse_data:
        jmp     parse_number

; Parses a mandatory comma beween arguments. Does not write any tokens.
; Returns carry clear if the ',' was found or carry set if it was not.
; Y SAFE

parse_argument_separator:
        jsr     skip_whitespace         ; Leaves next character in A
        cmp     #','                    ; Sets carry if character was ','
        bne     @error
        inc     bp
        clc
        rts

@error:
        sec
        rts

; Skip past any whitespace in the buffer. Returns the next character in A. The final value of bp is also left in X.
; bp = the read position (modified)
; Y SAFE, BC SAFE, DE SAFE

skip_whitespace:
        ldx     bp                      ; Use X to index buffer
@next:      
        lda     buffer,x        
        inx     
        cmp     #' '        
        beq     @next       
        dex                             ; It wasn't whitespace so go back
        stx     bp                      ; Update read position
        rts
