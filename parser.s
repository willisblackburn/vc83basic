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
        jsr     parse_statements
@blank_line:
        mva     line_pos, line_buffer+Line::next_line_offset    ; Write position is next line offset
        ldx     buffer_pos
        lda     buffer,x                ; Verify the line ends with 0 as expected
        raine   ERR_SYNTAX_ERROR        ; Nope, fail
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

parse_statements:
        ldax    #pvm_statements

; Fall through

; Invokes parsing virtual machine (PVM).
; CALL pushes a ParserState on the stack that can be retored with RETURN.
;   RETURN fails if the ParserState on the top of the stack did not come from CALL.
; TRY pushes a ParserState on the stack that will be restored with FAIL and discarded with COMMIT.
;   FAIL discards ParserStates created by CALL.
;   COMMIT fails if the ParserState on the top of the stack did not come from TRY.

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
        beq     @arguments              ; No address argument, check for arguments
        lda     (pvm_program_ptr),y
        sta     pvm_address_arg
        iny
        lda     (pvm_program_ptr),y
        sta     pvm_address_arg+1
        iny

; Look at the last three bits to figure out what arguments follow the instruction and load them.

@arguments:
        lda     B
        and     #$03                    ; Mask off bottom two bits
        cmp     #$03                    ; Check if it's expecting a string
        beq     @string                 ; If so go do it, otherwise, A is the number of arguments
        mvx     #1, D                   ; Default args are 1, 254
        mvx     #254, E
        tax                             ; X is now number of arguments to read
@next_argument:
        beq     @match                  ; No arguments
        mva     D, E                    ; Move previous arg over
        lda     (pvm_program_ptr),y     ; Get argument
        sta     D                       ; Replace first arg
        iny
        dex
        jmp     @next_argument

@string:
        jsr     rebase_pvm_program_ptr
        mvaa    pvm_program_ptr, DE     ; Save address of string as argument
        ldy     #$FF                    ; Now go looking for the character with bit 7 set that ends the string
@string_next:
        iny
        lda     (pvm_program_ptr),y
        bpl     @string_next     
        iny                             ; Skip the last one character and fall through to check address argument

; The arguments are parsed and Y points to the next PVM instruction.

@match:
        jsr     rebase_pvm_program_ptr  ; Catch up pvm_program_ptr to where Y is pointing to free up Y
        ldx     buffer_pos              ; Load up buffer position
        mvy     #0, C                   ; Now C is the match flag, default to false
        lda     B                       ; Recover the instruction from B
        cmp     #$10                    ; If "less than" the discard function, it's TEST or MATCH
        bcs     @instruction            ; Not TEST or MATCH, so skip the matching logic
        and     #$03                    ; Get address type again
        cmp     #$03                    ; Is it "match string?"
        beq     @match_string           ; Yep, go do it
        lda     buffer,x                ; It's "match char" or "match range;" get character from the buffer
        sec
        sbc     D                       ; Check if it's in range
        bcc     @instruction
        cmp     E
        bcs     @instruction
@match_any:
        inc     C                       ; Increment the match flag, making it true
        inx                             ; Move past the matched character
        bne     @instruction            ; Unconditional

@match_string:
        lda     (DE),y                  ; Load the next value from the string to match
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
        .word   ins_discard-1
        .word   ins_emit-1
        .word   0
        .word   ins_try-1
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
        stx     C                       ; Re-use C to save the match end position
        ldx     buffer_pos              ; Go back to beginning
@write_next:
        lda     buffer,x
        jsr     write_to_line_buffer
        inx
        cpx     C                       ; Caught up with end position?
        bne     @write_next
        stx     buffer_pos              ; Update buffer_pos
        rts

ins_emit:
        lda     D

; Fall through

; Write a single byte to line_buffer, checking for the maximum line length.
; X SAFE, BC SAFE, DE SAFE

write_to_line_buffer:
        ldy     line_pos                ; Write at line_pos
        cpy     #MAX_LINE_LENGTH
        raieq   ERR_LINE_TOO_LONG
        sta     line_buffer,y
        inc     line_pos
        rts

ins_try:
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
        rts

ins_discard:
        jsr     ins_commit              ; Do all the COMMIT stuff
        lda     stack+ParserState::line_pos,x
        sta     line_pos                ; And also restore line_pos
        rts

ins_jump:
        mvaa    pvm_address_arg, pvm_program_ptr
        rts

ins_fail:
        ldx     stack_pos               ; Check if stack is empty
        cpx     #PRIMARY_STACK_SIZE
        raieq   ERR_SYNTAX_ERROR        ; No TRY, so this FAIL fails the entire parse with syntax error
        jsr     pop_parser_state
        bcs     ins_fail                ; Parser state is from CALL; we should ignore
        lda     stack+ParserState::buffer_pos,x     ; Restore state from TRY
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
        bcc     ins_return              ; State was from TRY: ignore it which will implicitly COMMIT 

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
; If this test returns with carry clear, then this parser state came from TRY, and if set, then from CALL.
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
        stx     line_pos                ; Reset line_pos to the space after the token
        rts

ins_jump_keyword:
        mvaa    name_ptr, pvm_program_ptr
        rts

ins_compose:
        lda     D
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
        .byte   $04, <address, >address
    .elseif (.match(m, ""))
        .byte   $07
        .byte   <address, >address
        name m
    .else
        .byte   $05, <address, >address, m
    .endif
.endmacro

.macro TEST_RANGE m, n, address
    ; Note reverse order
    .byte   $06, <address, >address, n, m
.endmacro

.macro MATCH m
    .if (.match(m, *))
        .byte   $08
    .elseif (.match(m, ""))
        .byte   $0B
        name m
    .else
        .byte   $09, m
    .endif
.endmacro

.macro MATCH_RANGE m, n
    ; Note reverse order
    .byte   $0A, n, m
.endmacro

.macro DISCARD
    .byte   $10
.endmacro

.macro EMIT b
    .byte   $19, b
.endmacro

.macro TRY address
        .byte   $2C, <address, >address
.endmacro

.macro COMMIT
        .byte   $30
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


; TEST	            0000 0100 aaaa
; TEST	            0000 0101 aaaa nn
; TEST	            0000 0110 aaaa bb ee
; TEST	            0000 0111 aaaa ccc
; MATCH	            0000 1000
; MATCH	            0000 1001 nn
; MATCH	            0000 1010 bb ee
; MATCH	            0000 1011 ccc
; DISCARD     	    0001 0000
; EMIT   	        0001 1001 nn
; (unused)	        0010 0xxx
; TRY     	        0010 1100 aaaa
; COMMIT	        0011 0000
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

pvm_statements:
        CALL pvm_whitespace
        TEST 0, @done
        CALL pvm_statement
        TRY @done
        BEGIN_KEYWORD
        MATCH ':'
        CALL pvm_tokenize_misc
        COMMIT
        JUMP pvm_statements
@done:
        EMIT 0
        RETURN

pvm_statement:
        CALL pvm_whitespace
        BEGIN_KEYWORD
        CALL pvm_name
        TOKENIZE_KEYWORD statement_name_table
        JUMP_KEYWORD

; Argument lists

pvm_optional_arg_2:
        TRY @done
        CALL pvm_expression
        COMMIT
        TRY @done
        CALL pvm_whitespace
        MATCH ','
        CALL pvm_expression
@done:
        RETURN

; pvm_arg_list is list of 1-N expressions (but not 0).

pvm_arg_list:
        CALL pvm_expression
@next:
        TRY @done
        CALL pvm_whitespace
        MATCH ','
        CALL pvm_expression
        COMMIT
        JUMP @next
@done:
        RETURN

; Expressions

pvm_expression:
        CALL pvm_primary_expression
        TRY @done
        CALL pvm_operator
        COMMIT
        JUMP pvm_expression
@done:
        RETURN

; pvm_primary_expression does not discard whitespace.
; The component that can be a primary expression discard whitespace.

pvm_primary_expression:
        TRY @string
        CALL pvm_whitespace
        MATCH '('
        CALL pvm_expression
        CALL pvm_whitespace
        MATCH ')'
        RETURN
@string:
        TRY @number
        CALL pvm_string
        RETURN
@number:
        TRY @function
        CALL pvm_number
        RETURN
@function:
        TRY @variable
        CALL pvm_whitespace
        BEGIN_KEYWORD
        CALL pvm_name
        TRY @tokenize_function
        MATCH '$'
        COMMIT
@tokenize_function:
        TOKENIZE_KEYWORD function_name_table
        COMPOSE TOKEN_FUNCTION
        MATCH '('
        CALL pvm_arg_list
        CALL pvm_whitespace
        MATCH ')'
        RETURN
@variable:
        JUMP pvm_variable

; Low-level rules

pvm_number:
        CALL pvm_whitespace
        TEST '.', @initial_decimal
        CALL pvm_digits
        TRY @optional_e
        MATCH '.'
        COMMIT
@digits_after_decimal:
        TRY @optional_e
        CALL pvm_digits
        COMMIT
@optional_e:
        TRY @done
        MATCH 'E'
        CALL pvm_digits
        RETURN
@initial_decimal:
        MATCH *
        TRY @optional_e
        CALL pvm_digits
        COMMIT
        JUMP @optional_e
@done:
        RETURN

; pvm_digits does not remove whitespace.
; It is only used from pvm_number.

pvm_digits:
        MATCH_RANGE '0', 10
@next:
        TRY @done
        MATCH_RANGE '0', 10
        COMMIT
        JUMP @next
@done:
        RETURN

pvm_number_list:
        CALL pvm_number
@next:
        TRY @done
        CALL pvm_whitespace
        MATCH ','
        CALL pvm_number
        COMMIT
        JUMP @next
@done:
        RETURN

pvm_string:
        CALL pvm_whitespace
        MATCH '"'
@next:
        TEST '"', @first_quote
@second_quote:
        MATCH *
        JUMP @next
@first_quote:
        MATCH *
        TEST '"', @second_quote
        RETURN

pvm_variable:
        CALL pvm_whitespace
        CALL pvm_name
        TRY @eot
        MATCH '$'
        COMMIT
@eot:
        COMPOSE EOT
        TEST '(', @array
        RETURN
@array:
        MATCH *
        CALL pvm_arg_list
        MATCH ')'
        RETURN

pvm_variable_list:
        CALL pvm_variable
@next:
        TRY @done
        CALL pvm_whitespace
        MATCH ','
        CALL pvm_variable
        COMMIT
        JUMP @next
@done:
        RETURN

pvm_operator:
        CALL pvm_whitespace
        BEGIN_KEYWORD
        MATCH_RANGE ' ', 32
        TRY @end
        MATCH_RANGE '<', 3
        COMMIT
@end:
        TOKENIZE_KEYWORD operator_name_table
        COMPOSE TOKEN_OP
        RETURN        

; pvm_misc does not discard whitespace.
; Callers test for the correct keyword before calling and should discard whitespace at that point.

pvm_misc:
        BEGIN_KEYWORD
        CALL pvm_name
pvm_tokenize_misc:
        TOKENIZE_KEYWORD extra_name_table
        COMPOSE TOKEN_MISC
        RETURN

; Captures all text to EOL.

pvm_text:
        CALL pvm_whitespace
        TRY @done
        MATCH *
        COMMIT
        JUMP pvm_text
@done:
        RETURN
        
; pvm_name does not discard whitespace.
; Its only job is to capture an alphanumeric "name."

pvm_name:
        MATCH_RANGE 'A', 26
@next:
        TRY @digit
        MATCH_RANGE 'A', 26
        COMMIT
        JUMP @next
@digit:
        TRY @underscore
        MATCH_RANGE '0', 10
        COMMIT
        JUMP @next
@underscore:
        TRY @done
        MATCH '_'
        COMMIT
        JUMP @next        
@done:
        RETURN

pvm_whitespace:
        TRY @done
        MATCH ' '
        DISCARD
        JUMP pvm_whitespace
@done:
        RETURN

statement_name_table:
        name_table_entry "END"
            RETURN
:       name_table_entry "RUN"
            RETURN
:       name_table_entry "PRINT"
            JUMP pvm_expression
:       name_table_entry "LET"
            CALL pvm_variable
            MATCH '='
            JUMP pvm_expression
:       name_table_entry "INPUT"
            JUMP pvm_variable_list
:       name_table_entry "LIST"
            JUMP pvm_optional_arg_2
:       name_table_entry "GOTO"
            JUMP pvm_number
:       name_table_entry "GOSUB"
            JUMP pvm_number
:       name_table_entry "RETURN"
            RETURN
:       name_table_entry "POP"
            RETURN
:       name_table_entry "ON"
            CALL pvm_expression    
            CALL pvm_whitespace
            TEST "GO", @go
            FAIL
@go:
            CALL pvm_misc
            JUMP pvm_number_list
:       name_table_entry "FOR"
            CALL pvm_variable
            CALL pvm_whitespace
            MATCH '='
            CALL pvm_expression
            CALL pvm_whitespace
            TEST "TO", @to
            FAIL
@to:
            CALL pvm_misc
            CALL pvm_expression
            CALL pvm_whitespace
            TEST "STEP", @step
            RETURN
@step:
            CALL pvm_misc
            JUMP pvm_expression
:       name_table_entry "NEXT"
            JUMP pvm_variable
:       name_table_entry "STOP"
            RETURN
:       name_table_entry "CONT"
            RETURN
:       name_table_entry "IF"
            CALL pvm_expression
            CALL pvm_whitespace
            TEST "THEN", @then
            FAIL
@then:
            CALL pvm_misc
            JUMP pvm_statement
:       name_table_entry "NEW"
            RETURN
:       name_table_entry "CLR"
            RETURN
:       name_table_entry "DIM"
            JUMP pvm_variable
:       name_table_entry "REM"
            JUMP pvm_text
:       name_table_entry "DATA"
            JUMP pvm_text
:       name_table_entry "READ"
            JUMP pvm_variable_list
:       name_table_entry "RESTORE"
            JUMP pvm_number
:       name_table_entry "POKE"
:       name_table_end

extra_name_table:
        name_table_entry ":"
:       name_table_entry "THEN"
:       name_table_entry "GOTO"
:       name_table_entry "GOSUB"
:       name_table_entry "TO"
:       name_table_entry "STEP"
:       name_table_end

operator_name_table:
        name_table_entry "+"
:       name_table_entry "-"
:       name_table_entry "*"
:       name_table_entry "/"
:       name_table_entry "^"
:       name_table_entry "&"
:       name_table_entry "="
:       name_table_entry "<"
:       name_table_entry ">"
:       name_table_entry "<>"
:       name_table_entry "<="
:       name_table_entry ">="
:       name_table_entry "AND"
:       name_table_entry "OR"
:       name_table_end

unary_operator_name_table:
        name_table_entry "-"
:       name_table_entry "NOT"
:       .byte   0

function_name_table:
        name_table_entry "LEN"
:       name_table_entry "STR$"
:       name_table_entry "CHR$"
:       name_table_entry "ASC"
:       name_table_entry "LEFT$"
:       name_table_entry "RIGHT$"
:       name_table_entry "MID$"
:       name_table_entry "VAL"
:       name_table_entry "FRE"
:       name_table_entry "PEEK"
:       name_table_entry "ADR"
:       name_table_entry "USR"
:       name_table_entry "INT"
:       name_table_entry "ROUND"
:       name_table_entry "LOG"
:       name_table_entry "EXP"
:       name_table_entry "SIN"
:       name_table_entry "COS"
:       name_table_entry "TAN"
:       name_table_entry "ABS"
:       name_table_entry "SGN"
:       name_table_entry "SQR"
:       name_table_end

