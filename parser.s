.include "macros.inc"
.include "basic.inc"

.zeropage

; Read position
r: .res 1
; Write position
w: .res 1

signature_ptr: .res 2
argument_count: .res 1

; The write position of the repeated argument count in line_buffer
repeated_argument_count_w: .res 1

.code

; All "parse" functions use:
; buffer = the buffer containing the user-entered program source
; r = the read position in buffer (modified on success)
; line_buffer = the buffer containing the tokenized output
; w = the token write position in line_buffer (modified on success)

; Reads a number from the buffer.
; If the first character is not a number, then return an error. Otherwise, read up to the first non-digit.
; r = the read position in buffer
; Returns the number in AX, carry clear if ok, carry set if error

read_number:
        ldy     r                       ; Use Y to index buffer (since AX will hold the number)
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
        cpy     r                       ; Did we parse anything?
        beq     @nothing                ; Nope
        sty     r                       ; Update read position
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

; Parses and tokenizes a syntax element starting with a name.
; The last byte of buffer should be 0, which won't match anything. This avoids the need to keep checking
; the buffer length.
; This function is called recursively. It sets up name_ptr and Y and saves them on the stack prior to calling
; other functions so that those functions can call back in to this one.
; AX = pointer to the first entry of the name table
; signature_ptr = pointer to the first entry of the signature table
; Returns carry clear if the input matched a rule, or carry set if it didn't match any syntax rule.
; TODO: parse_syntax or parse_syntax_element?

parse_element:

; This whole first section uses Y to track the parse position in the name table entry pointed to by name_ptr.

        jsr     find_name               ; Sets Y to next byte in name table entry (AX passed to find_name)
        bcs     @error
        pha                             ; Save the returned name index
        jsr     encode_byte             ; Encode the statement name
        pla                             ; Recover the name index (doesn't affect carry)
        bcs     @error                  ; encode_byte error
        jsr     skip_signature_entries  ; Move signature_ptr to point to the signature for this element

; After a character sequence, Y will point to one of:
; 1. 0, meaning we matched the last sequence in the last name table entry; stop.
; 2. A character, which must be the *next* entry; stop.
; 3. An argument placeholder. In this case we keep reading arguments and/or character sequences.

@after_character_sequence:
        lda     (name_ptr),y            ; Check if there are any arguments to read
        beq     @success
        and     #$60                    ; If byte AND $60 is non-zero then it's another character sequence.
        bne     @success

; The next byte must be arguments.

@arguments:
        sty     n                       ; Save y (the name table entry position) in n
        lda     (name_ptr),y            ; Re-read name table byte
        jsr     parse_arguments
        bcs     @error
        ldy     n                       
        lda     (name_ptr),y            ; Re-read name table byte
        bmi     @success                ; If bit 7 set then all done
        iny                             ; Advance Y to the next position in the name table entry

; Just finished arguments. If there's a character sequence here then parse it, otherwise parse another argument.
; This section also uses Y to track the parse position.

        lda     (name_ptr),y
        and     #$60                    ; Is it a character sequence?
        beq     @arguments              ; Nope, go handle more arguments (Y is good)
        jsr     skip_whitespace
        jsr     match_character_sequence    ; Will advance Y past the matched sequence
        bcs     @error
        jmp     @after_character_sequence   ; If matched then continue, else fall through to @error (Y is good)

@success:
        clc

; We never jump to @error without carry being set so don't have to set it again.

@error:
        rts

argument_type_vectors:
        .word   parse_error             ; TYPE_NONE
        .word   parse_expression        ; TYPE_INT
        .word   parse_expression        ; TYPE_FLOAT
        .word   parse_expression        ; TYPE_INT | TYPE_FLOAT
        .word   parse_expression        ; TYPE_STRING
        .word   parse_error             ; TYPE_STRING | TYPE_INT
        .word   parse_error             ; TYPE_STRING | TYPE_FLOAT
        .word   parse_expression        ; TYPE_ANY
        .word   parse_variable          ; TYPE_VAR
        .word   parse_error             ; TYPE_CH
        .word   parse_error             ; TYPE_PROMPT
        .word   parse_error             ; TYPE_PRINT
        .word   parse_error             ; TYPE_THEN
        .word   parse_error             ; TYPE_STEP
        .word   parse_error             ; TYPE_TEXT
        .word   parse_error             ; unused

; Parses arguments from the buffer and tokenizes them.
; Arguments must be separated by ','.
; In this function we don't pay attention to the name table anymore; we're only concerned with parsing some
; number of arguments.
; ARGUMENT COUNT MUST BE AT LEAST 1.
; A = the number of arguments to parse; bit 3 is true if these arguments are optional

parse_arguments:
        sta     argument_count
        jsr     parse_argument_expression   ; Parse the argument value; sets argument_type
        bcs     @parse_failed
@value:
        dec     argument_count          ; One argument done
        beq     @success                ; All done parsing arguments
        jsr     parse_following_argument    ; Parse the next argument value; resets argument_type
        bcc     @value                  ; If separator parsed then continue with value, otherwise fail
@parse_failed:
        lda     argument_count          ; Load the argument count
        and     #NT_OPTIONAL            ; Mask the optional argument flag
        beq     @done                   ; Result was 0 so optional flag not set; fail
        lda     argument_count          ; Optional was set so prepare to store "no value" tokens
        and     #NT_MASK_ARGUMENT_COUNT ; Isolate the count
        tay                             ; Store in Y
@no_value:
        lda     #TOKEN_NO_VALUE
        jsr     encode_byte             ; Encode the "no value" token
        bcs     @done                   ; encode_byte error
        dey                             ; Done with one "no value"
        bne     @no_value               ; Loop if more
@success:
        clc                             ; Signal no error
@done:
        debug $20
        rts

; Parses an argument separator followed by an argument.
; Reverts the read and write positions if parsing either the separator or argument fails.
; argument_type = the type of this argument

parse_following_argument:
        ldpha   r                       ; Save read position
        jsr     parse_argument_separator
        bcs     @error
        jsr     parse_argument_expression
        bcs     @error
        pla                             ; Pop and discard the saved read position
        rts

@error:
        plsta   r                       ; Restore r
        rts

; Parses an argument expression.
; Since parsing the argument can recursively invoke the name table element parser with new values for name_ptr etc.,
; save the current values to the stack first.
; TODO: make sure there's enough room on the stack; detect parses that recurse too deeply.

parse_argument_expression:
        ldphaa  name_ptr                ; Save name_ptr, n, and signature_ptr
        ldpha   n
        ldpha   argument_count
        ldax    #argument_type_vectors
        jsr     parse_expression
        plsta   argument_count          
        plsta   n
        plstaa  name_ptr                ; Recover variables from stack
        rts

; Parse repeated values separated by delimiters.
; argument_type = the type of the argument, which will have the TYPE_REPEATED bit set

; parse_repeated_argument:
;         lda     argument_type           ; Load the argument type
;         and     #TYPE_MASK_CLEAR_REPEATED   ; Clear the TYPE_REPEATED bit
;         sta     argument_type           ; Store back so we don't recursively try to parse a repeated value
;         ldpha   w                       ; Save the w value to restore in case we fail to parse anything
;         lda     #0                      
;         jsr     encode_byte             ; Create a placeholder for the number of arguments; this will be at position w
;         jsr     parse_argument_expression   ; Parse the first value
;         bcc     @value                  ; Succees; continue parsing values
;         plsta   w                       ; Restore w (doesn't affect carry)
;         rts

; @value:
;         tsx                           
;         lda     $101,x                  ; Get the w that we saved on the stack earlier
;         tax                             ; w into X register
;         inc     line_buffer,x           ; Increment the argument count that we saved at that position
;         jsr     parse_following_argument
;         bcc     @value                  ; Keep parsing until we run out of arguments
;         pla                             ; Pop the original w value from the stack and discard it
;         clc                             ; Clear carry since it's set
;         rts

; Placeholder handler that just signals an error.

parse_error:
        sec
        rts

; Parses and tokenizes a expression.
; This function handles skipping whitespace for ALL expression elements.

parse_expression:
        jsr     skip_whitespace
        jsr     parse_number
        bcc     @done
        jsr     parse_variable
@done:
        rts

; Parses a number from the buffer.

parse_number:
        jsr     read_number
        bcs     @error
        jsr     encode_number           ; Will set carry if fail
@error:
        rts

; Parses a variable name.
; Tries to match the current buffer at position r with the names in the variable name table.
; If the name is not found, then extends the variable name table.

parse_variable:
        jsr     skip_whitespace
        ldx     r                       ; Load read position into X
        lda     buffer,x                ; Load current character
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

; Parses a mandatory comma beween arguments. Does not write any tokens.
; Returns carry clear if the ',' was found or carry set if it was not.
; Y SAFE

parse_argument_separator:
        jsr     skip_whitespace
        ldx     r
        lda     buffer,x
        cmp     #','                    ; Sets carry if character was ','
        bne     @error
        inx
        stx     r
        clc
        rts

@error:
        sec
        rts

; Skip past any whitespace in the buffer.
; This function is NOT exported because we want other modules to call parsing funtions, not this function.
; r = the read position (modified)
; Y SAFE, BC SAFE, DE SAFE

skip_whitespace:
        ldx     r                       ; Use X to index buffer
@next:      
        lda     buffer,x        
        inx     
        cmp     #' '        
        beq     @next       
        dex                             ; It wasn't whitespace so go back
        stx     r                       ; Update read position
        rts

; Moves signature_ptr forward by a certain number of entries of 2 bytes each (skip_signature_entries entry point)
; or by a certain number of argumnets of 1 byte each (skip_signature_arguments).
; A = the number of entries or arguments to skip (must be <128)

skip_signature_entries:
        asl                             ; Multiply the input value by 2.

skip_signature_arguments:
        clc
        adc     signature_ptr           
        sta     signature_ptr   
        bcc     @no_carry               ; Carry clear so don't need to increment high byte
        inc     signature_ptr+1
@no_carry:
        rts
