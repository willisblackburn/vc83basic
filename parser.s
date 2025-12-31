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
        ldax    #pvm_statements
        jsr     parse_pvm
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

; Invokes parsing virtual machine (PVM).
; AX = address of first PVM instruction

parse_pvm:
        stax    pvm_program_ptr
        jsr     run_pvm
        raics   ERR_SYNTAX_ERROR        ; If returning with carry set, raise syntax error
        lda     B
        cmp     #PVM_RETURN             ; Make sure we exited via RETURN
        raine   ERR_INTERNAL_ERROR
        rts

dispatch_pvm_instruction:
        and     #$0F                    ; Just the instruction index
        tay                             ; Transfer into Y
        ldax    #pvm_instruction_vectors
        jsr     invoke_indexed_vector

; Fall through

; Resume parsing instructions.
; Invoked recursively by CALL and TRY.
; Returns carry clear if the parse succeeded, or carry set if it failed.
; Returns with pvm_program_ptr pointing to the instruction after the the one that caused run_pvm to exit,
; and that instruction in B.

run_pvm:
        ldy     #0
        lda     (pvm_program_ptr),y     ; Load PVM instruction
        sta     B                       ; Park instruction in B
        iny
        jsr     rebase_pvm_program_ptr  ; Avoid rebasing individual single-byte instructions

; Handle the instruction

        lda     B                        
        bmi     dispatch_pvm_instruction    ; Instructions $80-FF are dispatched

; MATCH

        ldx     buffer_pos              ; Prepare to load the next character from the input
        cmp     #PVM_MATCH_RANGE_BASE   ; Check if it's a range match starting at $60
        bcc     @match_single
        and     #$1F                    ; The value remaining in A is the size of the range to match
        sta     C                       ; Store it in C
        lda     buffer,x
        beq     ins_fail                ; If we read NUL then fail immediately
        sbc     (pvm_program_ptr),y     ; Subtract away the starting character
        iny
        bcc     ins_fail                ; Out of range: too low
        cmp     C                       ; Check the range
        bcs     ins_fail                ; Out of range: too high
        bcc     @matched                ; Unconditional
@match_single:
        cmp     buffer,x
        bne     ins_fail
@matched:
        lda     buffer,x                ; Load and move past the matched character
        inc     buffer_pos
        jsr     write_to_line_buffer    ; Write it to the output
        bne     run_pvm                 ; Unconditional

ins_match_any:
        lda     buffer,x                ; Check next character
        beq     ins_fail                ; If it's NUL then treat as FAIL
        inc     buffer_pos

; JUMP: read address, replace pvm_program_ptr

ins_jump:
        jsr     read_address
        stax    pvm_program_ptr
        rts

; Instruction handlers must return to parse_pvm with pvm_program_ptr pointing to the next instruction.
; Returning from the instruction handler always continues execution at the next instruction. Instruction handlers can
; pop their own return address in order to cause a return from run_pvm.

; TRY: set a savepoint

ins_try:
        ldpha   line_pos
        ldpha   buffer_pos              ; Save input and output positions
        ldx     #0                      ; High byte of savepoint handler offset
        lda     (pvm_program_ptr),y     ; Low byte
        bpl     @positive               ; If positive, leave X = 0
        dex                             ; Otherwise X = -1
@positive:
        iny                             ; Advance past offset
        clc
        adc     pvm_program_ptr         ; Add to pvm_program_ptr
        pha
        txa
        adc     pvm_program_ptr+1
        pha
        ldpha   #0                      ; Can't be program pointer high byte, so signals this is a TRY handler
        jsr     rebase_pvm_program_ptr  ; Prepare to invoke parse_pvm at next instruction address
        jsr     run_pvm                 ; Go do it
        pla                             ; Discard TRY handler signal byte
        bcs     @error                  ; TRY exited with FAIL
        pla                             ; Discard the parser state
        pla
        pla                             ; Discard buffer_pos
        pla                             ; Leave line_pos in A
        ldx     B                       ; Handle non-FAIL instructions
        cpx     #PVM_RETURN             ; RETURN: keep returning until we reach a CALL or exit the parser
        beq     ins_return
        cpx     #PVM_ACCEPT             ; ACCEPT: throw away line_pos
        beq     @done
        sta     line_pos                ; DISCARD: restore line_pos from A, throwing away the output
@done:
        rts                             ; Just return; run_pvm leaves pvm_program_ptr pointing to next instruction

@error:
        plstaa  pvm_program_ptr         ; Resume at savepoint
        plsta   buffer_pos
        plsta   line_pos
        rts

; ACCEPT: accept input and pop savepoint
; DISCARD: like ACCEPT, but throws away the output
; RETURN: resume at the instruction following last call (implies ACCEPT if TRY is open)

ins_accept:
ins_discard:
ins_return:
        pla                             ; Discard own return address
        pla
        clc                             ; Signal success
        rts

; FAIL: return to the most recent savepoint, or fail the entire parse

ins_fail:
        pla                             ; Pop return address of ins_fail off the stack
        pla
        sec                             ; Carry set means failure
        rts                             ; Return to caller of pvm_parse

; CALL: save parser state on the stack, then perform JUMP

ins_call:
        jsr     read_address
        stax    BC                      ; Temporarily park the address
        jsr     rebase_pvm_program_ptr
        ldphaa  pvm_program_ptr         ; Save return address
        ldax    BC

do_call:
        stax    pvm_program_ptr
        jsr     run_pvm                 ; Go do it
        plstaa  pvm_program_ptr         ; Restore the program pointer from the stack
        bcs     ins_fail                ; CALL exited with FAIL; propagate failure
        lda     B                       ; If success, make sure we got here from RETURN
        cmp     #PVM_RETURN
        raine   ERR_INTERNAL_ERROR      ; Throw exception if ACCEPT or DISCARD without TRY
        rts

; BEGIN: mark the beginning of a keyword

ins_begin:
        mva     line_pos, decode_name_ptr           ; Set decode_name_ptr to start of name in line_buffer
        mvx     #>line_buffer, decode_name_ptr+1
        rts

; TOKENIZE: look up the name from the BEGIN point in a name table, emit the index

ins_tokenize:
        lda     #EOT
        jsr     compose_with_last_byte
        jsr     read_address
        jsr     find_name
        bcs     ins_fail                ; Didn't find the name; treat as FAIL
        ldx     decode_name_ptr
        sta     line_buffer,x           ; Write the token to line_buffer
        inx
        stx     line_pos                ; Reset line_pos to the space after the token
        ldy     #2                      ; Skip over name table address
        jmp     rebase_pvm_program_ptr

; DISPATCH: CALL the instruction following the end of the matched name in the name table

ins_dispatch:
        ldphaa  pvm_program_ptr         ; Save return address
        ldax    name_ptr                ; CALL to name_ptr
        jmp     do_call

; COMPOSE: OR the next byte value into the last byte written to the output

ins_compose:
        lda     (pvm_program_ptr),y     ; Get the address of the name table
        iny
compose_with_last_byte:
        ldx     line_pos                ; Current line_pos
        ora     line_buffer-1,x         ; Subtract one since we want last character
        sta     line_buffer-1,x
        jmp     rebase_pvm_program_ptr

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

; Retrieves the address from the instruction stream and returns in AX.
; Y must point to the address relative to pvm_program_ptr.
; Returns with incremented by 2.

read_address:
        lda     (pvm_program_ptr),y     ; Low byte of next instruction address
        pha                             ; Don't update pvm_program_ptr yet
        iny
        lda     (pvm_program_ptr),y     ; High byte
        tax                             ; Into X
        iny
        pla
        rts

; Rebases pvm_program_ptr by adding Y.
; Exits with Y=0.

rebase_pvm_program_ptr:
        tya                             ; Move offset into A and add to pvm_program_ptr
        ldy     #0                      ; Reset Y
        clc                             ; Not sure if carry is set or not so clear it now
        adc     pvm_program_ptr         ; Add to pvm_program_ptr
        sta     pvm_program_ptr
        bcc     @done
        inc     pvm_program_ptr+1
@done:
        rts

pvm_instruction_vectors:
        .word   ins_jump-1
        .word   ins_try-1
        .word   ins_accept-1
        .word   ins_discard-1
        .word   ins_fail-1
        .word   ins_call-1
        .word   ins_return-1
        .word   ins_begin-1
        .word   ins_tokenize-1
        .word   ins_dispatch-1
        .word   ins_compose-1
        .word   ins_match_any-1

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

.macro MATCH m
    .if (.match(m, *))
        .byte   $8B
    .elseif (.match(m, ""))
        .byte   m
    .else
        .byte   m
    .endif
.endmacro

.macro MATCH_RANGE start, end
        .assert (end - start + 1) < $20, error, "Match range must be <32 characters"
        .byte   $60 + (end - start + 1), start
.endmacro

.macro JUMP address
        .byte   $80, <address, >address
.endmacro

.macro TRY address
        .assert (address - *) >= -128 .and (address - *) <= 127, error, "Address offset out of range"
        .byte   $81, <(address - *)
.endmacro

.macro ACCEPT
        .byte   $82
.endmacro

.macro DISCARD
        .byte   $83
.endmacro

.macro FAIL
        .byte   $84
.endmacro

.macro CALL address
        .byte   $85, <address, >address
.endmacro

.macro RETURN
        .byte   $86
.endmacro

.macro BEGIN
        .byte   $87
.endmacro

.macro TOKENIZE address
        .byte   $88, <address, >address
.endmacro

.macro DISPATCH
        .byte   $89
.endmacro

.macro COMPOSE b
        .byte   $8A, b
.endmacro

; PVM program

pvm_statements:
;         CALL pvm_whitespace
;         TEST 0, @done
;         CALL pvm_statement
;         TRY @done
;         BEGIN_KEYWORD
;         MATCH ':'
;         CALL pvm_tokenize_misc
;         COMMIT
;         JUMP pvm_statements
; @done:
;         EMIT 0
;         RETURN

; pvm_statement:
;         CALL pvm_whitespace
;         BEGIN_KEYWORD
;         CALL pvm_name
;         TOKENIZE_KEYWORD statement_name_table
;         JUMP_KEYWORD

; ; Argument lists

; pvm_optional_arg_2:
;         TRY @done
;         CALL pvm_expression
;         COMMIT
;         TRY @done
;         CALL pvm_whitespace
;         MATCH ','
;         CALL pvm_expression
; @done:
;         RETURN

; ; pvm_arg_list is list of 1-N expressions (but not 0).

; pvm_arg_list:
;         CALL pvm_expression
; @next:
;         TRY @done
;         CALL pvm_whitespace
;         MATCH ','
;         CALL pvm_expression
;         COMMIT
;         JUMP @next
; @done:
;         RETURN

; Expressions

pvm_expression:
        MATCH '1'
;         CALL pvm_primary_expression
;         TRY @done
;         CALL pvm_operator
;         COMMIT
;         JUMP pvm_expression
; @done:
        RETURN

; ; pvm_primary_expression does not discard whitespace.
; ; The component that can be a primary expression discard whitespace.

; pvm_primary_expression:
;         TRY @string
;         CALL pvm_whitespace
;         MATCH '('
;         CALL pvm_expression
;         CALL pvm_whitespace
;         MATCH ')'
;         RETURN
; @string:
;         TRY @number
;         CALL pvm_string
;         RETURN
; @number:
;         TRY @function
;         CALL pvm_number
;         RETURN
; @function:
;         TRY @variable
;         CALL pvm_whitespace
;         BEGIN_KEYWORD
;         CALL pvm_name
;         TRY @tokenize_function
;         MATCH '$'
;         COMMIT
; @tokenize_function:
;         TOKENIZE_KEYWORD function_name_table
;         COMPOSE TOKEN_FUNCTION
;         MATCH '('
;         CALL pvm_arg_list
;         CALL pvm_whitespace
;         MATCH ')'
;         RETURN
; @variable:
;         JUMP pvm_variable

; ; Low-level rules

; pvm_number:
;         CALL pvm_whitespace
;         TEST '.', @initial_decimal
;         CALL pvm_digits
;         TRY @optional_e
;         MATCH '.'
;         COMMIT
; @digits_after_decimal:
;         TRY @optional_e
;         CALL pvm_digits
;         COMMIT
; @optional_e:
;         TRY @done
;         MATCH 'E'
;         CALL pvm_digits
;         RETURN
; @initial_decimal:
;         MATCH *
;         TRY @optional_e
;         CALL pvm_digits
;         COMMIT
;         JUMP @optional_e
; @done:
;         RETURN

; ; pvm_digits does not remove whitespace.
; ; It is only used from pvm_number.

; pvm_digits:
;         MATCH_RANGE '0', 10
; @next:
;         TRY @done
;         MATCH_RANGE '0', 10
;         COMMIT
;         JUMP @next
; @done:
;         RETURN

; pvm_number_list:
;         CALL pvm_number
; @next:
;         TRY @done
;         CALL pvm_whitespace
;         MATCH ','
;         CALL pvm_number
;         COMMIT
;         JUMP @next
; @done:
;         RETURN

; pvm_string:
;         CALL pvm_whitespace
;         MATCH '"'
; @next:
;         TEST '"', @first_quote
; @second_quote:
;         MATCH *
;         JUMP @next
; @first_quote:
;         MATCH *
;         TEST '"', @second_quote
;         RETURN

; pvm_variable:
;         CALL pvm_whitespace
;         CALL pvm_name
;         TRY @eot
;         MATCH '$'
;         COMMIT
; @eot:
;         COMPOSE EOT
;         TEST '(', @array
;         RETURN
; @array:
;         MATCH *
;         CALL pvm_arg_list
;         MATCH ')'
;         RETURN

; pvm_variable_list:
;         CALL pvm_variable
; @next:
;         TRY @done
;         CALL pvm_whitespace
;         MATCH ','
;         CALL pvm_variable
;         COMMIT
;         JUMP @next
; @done:
;         RETURN

; pvm_operator:
;         CALL pvm_whitespace
;         BEGIN_KEYWORD
;         MATCH_RANGE ' ', 32
;         TRY @end
;         MATCH_RANGE '<', 3
;         COMMIT
; @end:
;         TOKENIZE_KEYWORD operator_name_table
;         COMPOSE TOKEN_OP
;         RETURN        

; ; pvm_misc does not discard whitespace.
; ; Callers test for the correct keyword before calling and should discard whitespace at that point.

; pvm_misc:
;         BEGIN_KEYWORD
;         CALL pvm_name
; pvm_tokenize_misc:
;         TOKENIZE_KEYWORD extra_name_table
;         COMPOSE TOKEN_MISC
;         RETURN

; ; Captures all text to EOL.

; pvm_text:
;         CALL pvm_whitespace
;         TRY @done
;         MATCH *
;         COMMIT
;         JUMP pvm_text
; @done:
;         RETURN
        
; ; pvm_name does not discard whitespace.
; ; Its only job is to capture an alphanumeric "name."

; pvm_name:
;         MATCH_RANGE 'A', 26
; @next:
;         TRY @digit
;         MATCH_RANGE 'A', 26
;         COMMIT
;         JUMP @next
; @digit:
;         TRY @underscore
;         MATCH_RANGE '0', 10
;         COMMIT
;         JUMP @next
; @underscore:
;         TRY @done
;         MATCH '_'
;         COMMIT
;         JUMP @next        
; @done:
;         RETURN

pvm_whitespace:
        TRY @done
        MATCH ' '
        DISCARD
        JUMP pvm_whitespace
@done:
        RETURN

statement_name_table:
        name_table_entry "END"
;             RETURN
; :       name_table_entry "RUN"
;             RETURN
; :       name_table_entry "PRINT"
;             JUMP pvm_expression
; :       name_table_entry "LET"
;             CALL pvm_variable
;             MATCH '='
;             JUMP pvm_expression
; :       name_table_entry "INPUT"
;             JUMP pvm_variable_list
; :       name_table_entry "LIST"
;             JUMP pvm_optional_arg_2
; :       name_table_entry "GOTO"
;             JUMP pvm_number
; :       name_table_entry "GOSUB"
;             JUMP pvm_number
; :       name_table_entry "RETURN"
;             RETURN
; :       name_table_entry "POP"
;             RETURN
; :       name_table_entry "ON"
;             CALL pvm_expression    
;             CALL pvm_whitespace
;             TEST "GO", @go
;             FAIL
; @go:
;             CALL pvm_misc
;             JUMP pvm_number_list
; :       name_table_entry "FOR"
;             CALL pvm_variable
;             CALL pvm_whitespace
;             MATCH '='
;             CALL pvm_expression
;             CALL pvm_whitespace
;             TEST "TO", @to
;             FAIL
; @to:
;             CALL pvm_misc
;             CALL pvm_expression
;             CALL pvm_whitespace
;             TEST "STEP", @step
;             RETURN
; @step:
;             CALL pvm_misc
;             JUMP pvm_expression
; :       name_table_entry "NEXT"
;             JUMP pvm_variable
; :       name_table_entry "STOP"
;             RETURN
; :       name_table_entry "CONT"
;             RETURN
; :       name_table_entry "IF"
;             CALL pvm_expression
;             CALL pvm_whitespace
;             TEST "THEN", @then
;             FAIL
; @then:
;             CALL pvm_misc
;             JUMP pvm_statement
; :       name_table_entry "NEW"
;             RETURN
; :       name_table_entry "CLR"
;             RETURN
; :       name_table_entry "DIM"
;             JUMP pvm_variable
; :       name_table_entry "REM"
;             JUMP pvm_text
; :       name_table_entry "DATA"
;             JUMP pvm_text
; :       name_table_entry "READ"
;             JUMP pvm_variable_list
; :       name_table_entry "RESTORE"
;             JUMP pvm_number
; :       name_table_entry "POKE"
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
:       name_table_end

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
