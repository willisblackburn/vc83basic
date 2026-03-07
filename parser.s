; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

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
        mvax    #buffer, read_ptr       ; Set up read_ptr so parsing primitives work
        ldy     buffer_pos
        jsr     skip_whitespace
        jsr     string_to_fp_2          ; Parse line number
        sty     buffer_pos              ; Initialize buffer_pos to wherever the number ended
        bcs     @no_line_number         ; Line number was provided so store it
        jsr     truncate_fp_to_int      ; Truncate line number to integer
        bcc     @store_line_number
@no_line_number:
        lda     #$FF                    ; Otherwise store -1 ($FFFF) instead
        tax
@store_line_number:
        stax    line_buffer+Line::number
        ldy     buffer_pos
        jsr     skip_whitespace         ; Detect a blank line; returns non-blank character in A, may be zero
        beq     @finish_line            ; Was zero

; Parse one statement. The statement must be found because the line is not blank and this is either the first
; statement or we just parsed a ':'.

@next_statement:
        mva     line_pos, statement_line_pos        ; Save start of statement position
        inc     line_pos                ; Begin tokenizing statement at next position
        ldax    #pvm_statement
        jsr     parse_pvm
        lda     #0                      ; Store 0 at end of statement
        ldx     line_pos
        sta     line_buffer,x
        inc     line_pos
        lda     line_pos                ; Write position is next statement offset
        ldx     statement_line_pos      ; Store at start of statement
        sta     line_buffer,x
        ldy     buffer_pos              ; Look for statement separator
        jsr     skip_whitespace
        beq     @finish_line            ; Reached end of line
        iny                             ; Move past whatever other character it was and update buffer_pos
        sty     buffer_pos
        cmp     #':'                    ; If not EOL it has to be ':'
        beq     @next_statement         ; It was ':'
        bne     syntax_error            ; It wasn't

@finish_line:
        mva     line_pos, line_buffer+Line::next_line_offset    ; Write position is next line offset
        ldx     buffer_pos
        lda     buffer,x                ; Verify the line ends with 0 as expected
        bne     syntax_error            ; Nope, fail
        rts

syntax_error:
        raise   ERR_SYNTAX_ERROR

; Invokes parsing virtual machine (PVM).
; AX = address of first PVM opcode
; buffer_pos = where to read from buffer
; line_pos = where to write to line_buffer

parse_pvm:
        stax    pvm_program_ptr
        mvax    #buffer, read_ptr       ; Set up read_ptr so parsing primitives in util module work
        jsr     run_pvm
        bcs     syntax_error
        rts

; Resume processing opcodes.
; Returns carry clear if the parse succeeded, or carry set if it failed.
; Returns with pvm_program_ptr pointing to the opcode after the the one that caused run_pvm to exit,
; and that opcode in B.

; Stack frame:
;
;     SP+8      PVM return address low byte (note big-endian) (only if we came from CALL)
;     SP+7      PVM return address high byte
;     SP+6      run_pvm return address high byte
;     SP+5      run_pvm return address low byte
;     SP+4      Savepoint buffer_pos
;     SP+3      Savepoint line_pos
;     SP+2      TRY handler low byte (note big-endian)
;     SP+1      TRY handler high byte (0 = no try handler)
;     SP        Current stack pointer       

run_pvm:
        lda     #0                      ; Empty savepoint
        pha
        pha
        pha
        pha

update_savepoint_clear_handler:
        ldx     #0                      ; Set X=0 to clear high byte of savepoint

update_savepoint:
        stx     C                       ; Need X for stack access
        tsx
        sta     $102,x                  ; Handler low byte
        lda     C                       ; Get handler high byte back from C
        sta     $101,x
        lda     line_pos
        sta     $103,x
        lda     buffer_pos
        sta     $104,x

next_pvm:
        ldy     #0
        lda     (pvm_program_ptr),y     ; Load PVM opcode
        sta     B                       ; Park opcode in B
        iny
        jsr     rebase_pvm_program_ptr  ; Skip past the opcode byte
        lda     B                       ; Recover opcode from B

; Handle the opcode

        cmp     #PVM_ACCEPT
        bcc     @not_accept
        jsr     calculate_address_6
        stax    pvm_program_ptr         ; We're going to jump here
        jmp     update_savepoint_clear_handler

@not_accept:
        cmp     #PVM_TRY
        bcc     @not_try
        jsr     calculate_address_6
        jmp     update_savepoint

@not_try:
        cmp     #PVM_JUMP
        bcc     @not_jump
        jsr     calculate_address_12
@jump:
        stax    pvm_program_ptr
        jmp     next_pvm

@not_jump:
        cmp     #PVM_CALL
        bcc     @not_call
        jsr     calculate_address_12
        sta     C                       ; Temporarily park the call address
        ldphaa  pvm_program_ptr         ; Save return address
        lda     C
        stax    pvm_program_ptr
        jsr     run_pvm                 ; Go do it
        plax                            ; Restore the program pointer from the stack
        bcs     op_fail                 ; If carry set, keep failing (the CALL failed)
        bcc     @jump

@not_call:
        cmp     #PVM_MATCH
        bcc     @not_match
        ldx     buffer_pos              ; Buffer position
        cmp     buffer,x
        bne     op_fail                 ; If no match, act like FAIL
        inc     buffer_pos
        jsr     write_to_line_buffer
        jmp     next_pvm

@not_match:
        tay                             ; Move opcode into Y: clobbers 0 that is there
        ldax    #pvm_opcode_vectors
        jmp     invoke_indexed_vector   ; Go do it

; FAIL: invoke the TRY handler, or fail the entire parse

op_fail:
        tsx                             ; Check savepoint on stack
        sec                             ; Set carry in case there's no handler
        lda     $101,x
        beq     return_carry
        sta     pvm_program_ptr+1       ; There is a handler; restore savepoint and continue
        lda     $102,x
        sta     pvm_program_ptr
        lda     $103,x
        sta     line_pos
        lda     $104,x
        sta     buffer_pos
        jmp     update_savepoint_clear_handler

; MATCH_RANGE: Range match
; First byte is the length of the range. If 0, stop. Second byte is the start of the range. Attempts ranges until
; one matches or none match (producing FAIL).

op_match_range:
        ldy     #0                      ; Reload Y with 0
@next_range:
        lda     (pvm_program_ptr),y     ; Length
        beq     op_fail                 ; We're out of match ranges: fail
        iny
        sta     C                       ; Store the range
        ldx     buffer_pos              ; Buffer position
        lda     buffer,x                ; Get character
        sec
        sbc     (pvm_program_ptr),y     ; Compare to first character
        iny
        bcc     @next_range             ; No match: character was too low
        cmp     C                       ; Compare with C
        bcs     @next_range             ; No match: character was too high
@find_zero:
        lda     (pvm_program_ptr),y     ; Find the end of the match range
        beq     @done
        iny
        iny
        bne     @find_zero
@done:
        iny
        jsr     rebase_pvm_program_ptr  ; Update pvm_program_ptr

; Fall through

op_match_any:
        ldx     buffer_pos
        lda     buffer,x
        beq     op_fail                 ; The 0 at the end of the line never matches
        inc     buffer_pos
        jsr     write_to_line_buffer
        jmp     next_pvm

; TOKENIZE: look up the name from the BEGIN point in a name table, emit the index

op_tokenize:
        lda     #EOT
        jsr     compose_with_last_byte
        tsx
        lda     $103,x                  ; Get line_pos from savepoint
        sta     decode_name_ptr         ; Start matching the name from savepoint
        lda     #>line_buffer           ; High byte
        sta     decode_name_ptr+1
        jsr     read_address
        jsr     find_name
        bcs     op_fail                 ; Didn't find the name; treat as FAIL
        ldx     decode_name_ptr
        sta     line_buffer,x           ; Write the token to line_buffer
        inx
        stx     line_pos                ; Reset line_pos to the space after the token
        jmp     next_pvm

; DISPATCH: JUMP to the address following the end of the matched name in the name table

op_dispatch:
        mvax    name_ptr, pvm_program_ptr   ; JUMP to name_ptr
        jmp     next_pvm

; RETURN: resume at the opcode following last call

op_return:
        clc                             ; Carry clear = success
return_carry:
        pla                             ; Discard savepoint
        pla
        pla
        pla
        rts

; WS: skip over whitespace

op_ws:
        ldy     buffer_pos
        jsr     skip_whitespace
        sty     buffer_pos
        jmp     next_pvm

; EMIT: output a byte

op_emit:
        ldy     #0
        lda     (pvm_program_ptr),y     ; Get argument
        jsr     write_to_line_buffer
        jmp     rebase_next_pvm

; COMPOSE: OR the next byte value into the last byte written to the output

op_compose:
        ldy     #0
        lda     (pvm_program_ptr),y     ; Get argument
        jsr     compose_with_last_byte
rebase_next_pvm:
        ldy     #1
        jsr     rebase_pvm_program_ptr  ; Advance past byte
        jmp     next_pvm
        
compose_with_last_byte:
        ldx     line_pos                ; Current line_pos
        ora     line_buffer-1,x         ; Subtract one since we want last character
        sta     line_buffer-1,x
        rts

; ARGSEP: skip over argument separator ','

op_argsep:
        ldy     buffer_pos
        jsr     read_argument_separator
        bcc     @found
        jmp     op_fail
@found:
        sty     buffer_pos
        lda     #','
        jsr     write_to_line_buffer
        jmp     next_pvm

pvm_opcode_vectors:
        .word   op_fail-1
        .word   op_return-1
        .word   op_ws-1
        .word   op_match_range-1
        .word   op_match_any-1
        .word   op_compose-1
        .word   op_argsep-1
        .word   op_tokenize-1
        .word   op_dispatch-1
        .word   op_emit-1

; Write a single byte to line_buffer, checking for the maximum line length.
; X SAFE, BC SAFE, DE SAFE

write_to_line_buffer:
        ldy     line_pos                ; Write at line_pos
        cpy     #MAX_LINE_LENGTH
        raieq   ERR_LINE_TOO_LONG
        sta     line_buffer,y
        inc     line_pos
        rts

; Retrieves the address from the PVM stream and returns in AX.
; pvm_program_ptr must point to the address.

read_address:
        ldy     #0
        lda     (pvm_program_ptr),y     ; Low byte of next opcode address
        pha                             ; Don't update pvm_program_ptr yet
        iny
        lda     (pvm_program_ptr),y     ; High byte
        tax                             ; Into X
        iny
        bne     rebase_pop

; Calculates the address of TRY or ACCEPT using the 6-bit offset embedded in the opcode relative to
; the current pvm_program_ptr value.
; A = the opcode

calculate_address_6:
        ldx     #0                      ; High byte of address offset
        and     #$3F                    ; Ignore top two bits of opcode
        cmp     #$20                    ; Test bit 5, which is the sign bit of the offset field
        bcc     add_to_pvm_program_ptr  ; Was positive so just leave it
        ora     #$C0                    ; Sign extend to high nybble
        dex                             ; And to high byte
        bne     add_to_pvm_program_ptr  ; Unconditional

; Calculates the address of JUMP or CALL using 4 bits from the opcode plus the next byte, for 12 bits total.
; A = the opcode

calculate_address_12:
        and     #$0F                    ; Ignore top four bits of opcode
        cmp     #$08                    ; Test bit 3, which is the sign bit of the offset field
        bcc     @positive               ; Was positive so just leave it
        ora     #$F0                    ; Sign extend to high nybble
@positive:
        tax                             ; Save high byte
        lda     (pvm_program_ptr),y     ; Read the low byte
        iny
add_to_pvm_program_ptr:
        clc
        adc     pvm_program_ptr         ; Add to pvm_program_ptr
        pha
        txa
        adc     pvm_program_ptr+1
        tax
rebase_pop:
        jsr     rebase_pvm_program_ptr  ; Address low byte is on stack and high byte is safe in X
        pla
        rts

; Rebases pvm_program_ptr by adding Y.
; Exits with Y=0.
; X SAFE, BC SAFE, DE SAFE

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
    .else
        ; If string is empty then just output a single EOT byte.
        .byte   EOT
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
        .byte   PVM_MATCH_ANY
    .elseif (.match(m, ""))
        .byte   m
    .else
        .byte   m
    .endif
.endmacro

.macro write_range start, end
        .byte (end - start) + 1, start
.endmacro

.macro write_all_ranges r1, r2, r3, r4
    ; Check if the first argument is blank. If it is, we are done with the list: exit.
    .ifblank r1
        .byte 0
        .exitmacro
    .endif

    ; Output the current pair.
    write_range r1

    ; Recursively call the macro with the remaining arguments.
    write_all_ranges {r2}, {r3}, {r4}
.endmacro

.macro MATCH_RANGE r1, r2, r3, r4
        .byte PVM_MATCH_RANGE
        write_all_ranges {r1}, {r2}, {r3}, {r4}
.endmacro

; Use (* + 1) because we add offset to address after skipping the opcode.
; But when writing the second byte of a far opcode, use * because it's now advanced one byte. 

.macro write_near_opcode opcode, address
        .assert (address - (* + 1)) >= -32 .and (address - (* + 1)) <= 31, error, "Address offset out of range"
        .byte   opcode + <(address - (* + 1)) & $3F
.endmacro

.macro write_far_opcode opcode, address
        .assert (address - (* + 1)) >= -1024 .and (address - (* + 1)) <= 1023, error, "Address offset out of range"
        .byte   opcode + >(address - (* + 1)) & $0F, <(address - *)
.endmacro

.macro TRY address
        write_near_opcode PVM_TRY, address
.endmacro

.macro ACCEPT address
        write_near_opcode PVM_ACCEPT, address
.endmacro

.macro JUMP address
        write_far_opcode PVM_JUMP, address
.endmacro

.macro CALL address
        write_far_opcode PVM_CALL, address
.endmacro

.macro FAIL
        .byte   PVM_FAIL
.endmacro

.macro RETURN
        .byte   PVM_RETURN
.endmacro

.macro WS
        .byte   PVM_WS
.endmacro

.macro COMPOSE b
        .byte   PVM_COMPOSE, b
.endmacro

.macro ARGSEP
        .byte   PVM_ARGSEP
.endmacro

.macro TOKENIZE address
        .byte   PVM_TOKENIZE, <address, >address
.endmacro

.macro DISPATCH
        .byte   PVM_DISPATCH
.endmacro

.macro EMIT b
        .byte   PVM_EMIT, b
.endmacro

; PVM program

pvm_statement:
        WS
        TRY @extension                  ; Sets savepoint and start of keyword
        CALL pvm_statement_name
        TOKENIZE statement_name_table
        DISPATCH                        ; Note: performs JUMP

@extension:
        TRY @impl_let                   ; Look for an extension statement
        CALL pvm_name
        TOKENIZE ex_statement_name_table
        COMPOSE TOKEN_EXTENSION
        DISPATCH

@impl_let:
        EMIT ST_IMPL_LET                ; Try implied LET

pvm_let:
        CALL pvm_var
        WS
        MATCH '='

; Fall through

; Expressions

pvm_expression:
        CALL pvm_primary_expression
        WS
        TRY @done               
        CALL pvm_binary_operator_name
        TOKENIZE operator_name_table
        COMPOSE TOKEN_OP
        ACCEPT pvm_expression
@done:
        RETURN

pvm_primary_expression:
        WS
        TRY @string
        MATCH '('
        CALL pvm_expression
        WS
        MATCH ')'
        RETURN
@string:
        TRY @number
        CALL pvm_string
        RETURN
@number:
        TRY @unary_operator
        CALL pvm_number
        RETURN
@unary_operator:
        TRY @function
        CALL pvm_unary_operator_name
        TOKENIZE unary_operator_name_table
        COMPOSE TOKEN_UNARY_OP
        ACCEPT pvm_primary_expression
@function:
        TRY pvm_var
        CALL pvm_function
        RETURN

; pvm_var_list is list of 1-N (but not 0) variables.

pvm_var_list:
        CALL pvm_var
        TRY @done
        ARGSEP
        ACCEPT pvm_var_list
@done:
        RETURN

; var ::= _ name '$'? ('(' arg_list _ ')')?

pvm_var:
        WS
        CALL pvm_name
        CALL pvm_opt_type
        COMPOSE EOT
        TRY @done
        CALL pvm_paren_arg_list
@done:
        RETURN

; Argument lists

pvm_arg_2:
        CALL pvm_expression
        ARGSEP
        JUMP pvm_expression

; pvm_arg_list is list of 1-N (but not 0) expressions.

pvm_arg_list:
        CALL pvm_expression
        TRY @done
        ARGSEP
        JUMP pvm_arg_list
@done:
        RETURN

; pvm_paren_arg_list is a list of 1-N (but not 0) expressions surrounded by parentheses.

pvm_paren_arg_list:
        WS
        MATCH '('
        CALL pvm_arg_list
        WS
        MATCH ')'
        RETURN

; pvm_print_expression is the particular kind of expression in the PRINT statement.

pvm_print_expression:
        WS
        TRY @not_comma
        MATCH ','
        ACCEPT pvm_print_expression
@not_comma:
        TRY @not_semi
        MATCH ';'
        ACCEPT pvm_print_expression
@not_semi:
        TRY @done
        CALL pvm_expression
        ACCEPT pvm_print_expression
@done:
        RETURN

pvm_unary_operator_name:
        TRY @not_name
        CALL pvm_name
        RETURN
@not_name:
        MATCH '-'
        RETURN

pvm_binary_operator_name:
        TRY @not_name
        CALL pvm_name
        RETURN
@not_name:
        MATCH_RANGE {'&', '?'}, {'^', '^'}
        TRY @done
        MATCH_RANGE {'<', '>'}
@done:
        RETURN

pvm_function:
        EMIT TOKEN_FUNCTION
        CALL pvm_function_call
        RETURN

pvm_function_call:
        CALL pvm_name
        CALL pvm_opt_type
        TOKENIZE function_name_table
        CALL pvm_paren_arg_list
        RETURN

pvm_opt_type:
        TRY @done
        MATCH '$'
@done:
        RETURN

; Low-level rules

; pvm_number_list is list of 1-N (but not 0) numbers.

pvm_number_list:
        CALL pvm_number
        TRY @done
        ARGSEP
        ACCEPT pvm_number_list
@done:
        RETURN

pvm_opt_number_2:
        TRY pvm_opt_number_done         ; First arg is optional
        CALL pvm_number
        TRY pvm_opt_number_done         ; Second arg is optional
        ARGSEP
        CALL pvm_number
        RETURN

pvm_opt_number:
        TRY pvm_opt_number_done
        CALL pvm_number
pvm_opt_number_done:
        RETURN

; number ::= _ opt_sign ((digits decimal_digits?) | decimal_digits) ('E' opt_sign digits)
; decimal_digits ::= ('.' opt_digits)
; digits ::= digit+
; opt_digits ::= digit*
; opt_sign ::= '-'?

pvm_number:
        WS
        CALL pvm_opt_sign
        TRY @alt
        CALL pvm_digits
        TRY @e
@alt:
        CALL pvm_decimal_digits
@e:
        TRY @done
        MATCH 'E'
        CALL pvm_opt_sign
        CALL pvm_digits
@done:
        RETURN

pvm_opt_sign:
        TRY @done
        MATCH '-'
@done:
        RETURN

; pvm_digits does not remove whitespace.
; It is only used from pvm_number.

pvm_decimal_digits:
        MATCH '.'
pvm_opt_digits:
        TRY pvm_digits_done
pvm_digits:
        MATCH_RANGE {'0', '9'}
        ACCEPT pvm_opt_digits
pvm_digits_done:
        RETURN

; string ::= _ '"' ('""' | [^"])* '"' 

pvm_string:
        WS
        MATCH '"'
@next:
        TRY @non_quote
        MATCH '"'
        TRY @done
        MATCH '"'
        ACCEPT @next
@non_quote:
        MATCH *
        ACCEPT @next
@done:
        RETURN

; Captures all text to EOL.

pvm_text:
        WS
@next:
        TRY @done
        MATCH *
        ACCEPT @next
@done:
        RETURN
        
pvm_statement_name:
        TRY pvm_name
        MATCH '?'                       ; A statement name can be '?', other names can't
        RETURN

; pvm_name does not discard whitespace.
; Its only job is to capture an alphanumeric "name."

pvm_name:
        MATCH_RANGE {'A', 'Z'}
@next:
        TRY @done
        MATCH_RANGE {'A', 'Z'}, {'0', '9'}, {'_', '_'}
        ACCEPT @next
@done:
        RETURN

statement_name_table:
        name_table_entry "LET"
            JUMP pvm_let
:       name_table_entry ""             ; Implied LET: won't ever match
:       name_table_entry "RUN"
            RETURN
:       name_table_entry "PRINT"
            JUMP pvm_print_expression
:       name_table_entry "?"
            JUMP pvm_print_expression
:       name_table_entry "LIST"
            JUMP pvm_opt_number_2
:       name_table_entry "GOTO"
            JUMP pvm_number
:       name_table_entry ""             ; Implied GOTO: won't ever match
:       name_table_entry "GOSUB"
            JUMP pvm_number
:       name_table_entry "RETURN"
            RETURN
:       name_table_entry "POP"
            RETURN
:       name_table_entry "ON"
            CALL pvm_expression    
            WS
            CALL pvm_goto_gosub
            JUMP pvm_number_list
:       name_table_entry "FOR"
            CALL pvm_var
            WS
            MATCH '='
            CALL pvm_expression
            WS
            CALL pvm_to
            CALL pvm_expression
            TRY @for_done
            WS
            CALL pvm_step
            JUMP pvm_expression
@for_done:
            RETURN
:       name_table_entry "NEXT"
            JUMP pvm_var
:       name_table_entry "STOP"
            RETURN
:       name_table_entry "CONT"
            RETURN
:       name_table_entry "NEW"
            RETURN
:       name_table_entry "CLR"
            RETURN
:       name_table_entry "DIM"
            JUMP pvm_var
:       name_table_entry "REM"
            JUMP pvm_text
:       name_table_entry "DATA"
            JUMP pvm_text
:       name_table_entry "READ"
            JUMP pvm_var_list
:       name_table_entry "RESTORE"
            JUMP pvm_opt_number
:       name_table_entry "POKE"
            JUMP pvm_arg_2
:       name_table_entry "END"
            RETURN
:       name_table_entry "INPUT"
            TRY @vars
            CALL pvm_string
            WS
            MATCH ';'
            ACCEPT @vars
@vars:
            JUMP pvm_var_list
:       name_table_entry "IF"
            CALL pvm_expression
            WS
            CALL pvm_then
            TRY @then_statement
            EMIT ST_IMPL_GOTO
            CALL pvm_number
            RETURN
@then_statement:
            JUMP pvm_statement
:       name_table_end

pvm_then:
        MATCH "THEN"
        JUMP pvm_clause
        
pvm_goto_gosub:
        MATCH "GO"
        CALL pvm_name
        JUMP pvm_clause
        
pvm_to:
        MATCH "TO"
        JUMP pvm_clause

pvm_step:
        MATCH "STEP"

; Fall through

pvm_clause:
        TOKENIZE clause_name_table
        COMPOSE TOKEN_CLAUSE
        RETURN

clause_name_table:
        name_table_entry "THEN"
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
:       name_table_entry "ATN"
:       name_table_entry "ABS"
:       name_table_entry "SGN"
:       name_table_entry "SQR"
:       name_table_entry "RND"
:       name_table_end
