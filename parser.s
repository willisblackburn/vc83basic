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
        mva     #0, buffer_pos          ; Initialize the read pointer
        sta     line_pos                ; Initialize write pointer
        ldax    #pvm_line

; Fall through

; Invokes parsing virtual machine (PVM).
; AX = address of first PVM instruction
; buffer_pos = where to read from buffer
; line_pos = where to write to line_buffer

parse_pvm:
        stax    pvm_program_ptr
        mvax    #buffer, read_ptr       ; Set up read_ptr so parsing primitives in util module work
        jsr     run_pvm
        raics   ERR_SYNTAX_ERROR        ; If returning with carry set, raise syntax error
        rts

; Resume parsing instructions.
; Invoked recursively by CALL and TRY.
; Returns carry clear if the parse succeeded, or carry set if it failed.
; Returns with pvm_program_ptr pointing to the instruction after the the one that caused run_pvm to exit,
; and that instruction in B.

run_pvm:

; Stack frame:
;
;     SP+8      PVM return address low byte (note big-endian) (only if we came from CALL)
;     SP+7      PVM return address high byte
;     SP+6      run_pvm return address high byte
;     SP+5      run_pvm return address low byte
;     SP+4      Savepoint buffer_pos
;     SP+3      Savepoint line_pos
;     SP+2      TRY handler low byte (note big-endian)
;     SP+1      TRY handler high byte
;     SP        Current stack pointer       

        lda     #0                      ; Empty savepoint
        pha
        pha
        pha
        pha

next_pvm:
        ldy     #0
        lda     (pvm_program_ptr),y     ; Load PVM instruction
        sta     B                       ; Park instruction in B
        iny
        jsr     rebase_pvm_program_ptr  ; Skip past the instruction byte
        lda     B                       ; Recover instruction from B

; Handle the instruction

        cmp     #PVM_JUMP
        bcc     @not_jump
        jsr     calculate_address
        jmp     jump

@not_jump:
        cmp     #PVM_CALL
        bcc     @not_call
        jsr     calculate_address
        jmp     call

@not_call:
        cmp     #PVM_TRY
        bcc     @not_try
        and     #$1F                    ; Ensure bit 5 is 0 so the 5-bit offset is resolved as a forward value
        jsr     calculate_address
        stx     C                       ; Need X for the stack
        tsx
        sta     $102,x                  ; Handler low byte
        lda     C                       ; Get high byte back from C
        sta     $101,x                  ; Handler low byte
        lda     line_pos
        sta     $103,x
        lda     buffer_pos
        sta     $104,x
        jmp     next_pvm

@not_try:
        cmp     #PVM_MATCH
        bcc     @not_match
        ldx     buffer_pos              ; Buffer position
        cmp     buffer,x
        bne     ins_fail                ; If no match, act like FAIL
        inc     buffer_pos
        jsr     write_to_line_buffer
        jmp     next_pvm

@not_match:
        tay                             ; Move instruction into Y: clobbers 0 that is there
        ldax    #pvm_instruction_vectors
        jmp     invoke_indexed_vector   ; Go do the instruction

pvm_instruction_vectors:
        .word   ins_fail-1
        .word   ins_return-1
        .word   ins_far_call-1
        .word   ins_far_jump-1
        .word   ins_ws-1
        .word   ins_match_range-1
        .word   ins_match_any-1
        .word   ins_compose-1
        .word   ins_argsep-1

        ; .word   ins_begin-1
        ; .word   ins_tokenize-1
        ; .word   ins_dispatch-1
        ; .word   ins_emit-1
        ; .word   ins_int-1
        ; .word   ins_eol-1
        ; .word   ins_link-1
        ; .word   ins_discard-1

; FAIL: invoke the TRY handler, or fail the entire parse

ins_fail:
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
        lda     #0
        sta     $101,x                  ; Zero out handler high address so future FAIL will actually fail
        jmp     next_pvm                ; Continue

; FAR_CALL: save parser state on the stack, then perform JUMP

ins_far_call:
        jsr     read_address
call:
        sta     B                       ; Temporarily park the call address
        jsr     rebase_pvm_program_ptr
        ldphaa  pvm_program_ptr         ; Save return address
        lda     B
        stax    pvm_program_ptr
        jsr     run_pvm                 ; Go do it
        plax                            ; Restore the program pointer from the stack
        bcs     ins_fail                ; If carry set, keep failing (the CALL failed)
        bcc     jump

; FAR_JUMP: read address, replace pvm_program_ptr

ins_far_jump:
        jsr     read_address
jump:
        stax    pvm_program_ptr
        jmp     next_pvm

; MATCH_RANGE: Range match
; First byte is the length of the range. If 0, stop. Second byte is the start of the range. Attempts ranges until
; one matches or none match (producing FAIL).

ins_match_range:
        ldy     #0                      ; Reload Y with 0
@next_range:
        lda     (pvm_program_ptr),y     ; Length
        beq     ins_fail                ; We're out of match ranges: fail
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

ins_match_any:
        ldx     buffer_pos
        lda     buffer,x
        beq     ins_fail                ; The 0 at the end of the line never matches
        inc     buffer_pos
        jsr     write_to_line_buffer
        jmp     next_pvm

; RETURN: resume at the instruction following last call

ins_return:
        clc                             ; Carry clear = success
return_carry:
        pla                             ; Discard savepoint
        pla
        pla
        pla
        rts

; WS: skip over whitespace

ins_ws:
        ldy     buffer_pos
        jsr     skip_whitespace
        sty     buffer_pos
        jmp     next_pvm

; COMPOSE: OR the next byte value into the last byte written to the output

ins_compose:
        ldy     #0
        lda     (pvm_program_ptr),y     ; Get argument
        jsr     compose_with_last_byte
        iny
        jsr     rebase_pvm_program_ptr  ; Advance past byte
        jmp     next_pvm
        
compose_with_last_byte:
        ldx     line_pos                ; Current line_pos
        ora     line_buffer-1,x         ; Subtract one since we want last character
        sta     line_buffer-1,x
        rts



; ; INT: parse and encode a 16-bit integer.

; ins_int:
;         ldy     buffer_pos
;         jsr     string_to_fp_2          ; Parse line number
;         bcs     ins_fail                ; If no number then just fail
;         sty     buffer_pos              ; Update buffer_pos
;         jsr     truncate_fp_to_int      ; Truncate number to integer
;         jsr     write_to_line_buffer    ; Write out the low byte
;         txa                             ; and the high byte
;         jmp     write_to_line_buffer

; ; EOL: fail if we're not at EOL

; ins_eol:
;         ldx     buffer_pos
;         lda     buffer,x
;         bne     ins_fail
;         rts

; ; BEGIN: mark the beginning of a keyword

; ins_begin:
;         mva     line_pos, decode_name_ptr           ; Set decode_name_ptr to start of name in line_buffer
;         mvx     #>line_buffer, decode_name_ptr+1
;         rts

; ; TOKENIZE: look up the name from the BEGIN point in a name table, emit the index

; ins_tokenize:
;         lda     #EOT
;         jsr     compose_with_last_byte
;         jsr     read_address
;         jsr     find_name
;         bcs     ins_fail                ; Didn't find the name; treat as FAIL
;         ldx     decode_name_ptr
;         sta     line_buffer,x           ; Write the token to line_buffer
;         inx
;         stx     line_pos                ; Reset line_pos to the space after the token
;         ldy     #2
;         jmp     rebase_pvm_program_ptr  ; Skip over the name table address

; ; DISPATCH: CALL the instruction following the end of the matched name in the name table

; ins_dispatch:
;         mvax    name_ptr, pvm_program_ptr   ; JUMP to name_ptr
;         rts

; ; EMIT: just output one byte

; ins_emit:
;         ldy     #0
;         lda     (pvm_program_ptr),y     ; Get the value to output
;         jsr     write_to_line_buffer
;         ldy     #1
;         jmp     rebase_pvm_program_ptr

; ; LINK: save space for link byte, resume, write length on success

; ins_link:
;         ldpha   line_pos                ; Push current line_pos
;         inc     line_pos                ; Output from next position
;         jsr     run_pvm
;         pla                             ; Original line_pos into A
;         tay                             ; And Y
;         lda     line_pos                ; Current line_pos
;         sta     line_buffer,y           ; Save into the link position
;         pla                             ; Propagate return with carry unchanged
;         pla
;         rts

; ; DISCARD: discards the previously-emitted byte

; ins_discard:
;         dec     line_pos
;         rts


; ARGSEP: skip over argument separator ','

ins_argsep:
        ldy     buffer_pos
        jsr     read_argument_separator
        bcc     @found
        jmp     ins_fail
@found:
        sty     buffer_pos
        lda     #','
        jsr     write_to_line_buffer
        jmp     next_pvm

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
; pvm_program_ptr must point to the address.
; Returns with Y=2.

read_address:
        ldy     #0
        lda     (pvm_program_ptr),y     ; Low byte of next instruction address
        pha                             ; Don't update pvm_program_ptr yet
        iny
        lda     (pvm_program_ptr),y     ; High byte
        tax                             ; Into X
        iny
        pla
        rts

; Calculates the address of a TRY or relative CALL or JUMP instruction.
; A = the instruction byte

calculate_address:
        ldx     #0                      ; High byte of address offset
        and     #$3F                    ; Ignore top two bits of instruction byte
        cmp     #$20                    ; Test bit 5, which is the sign bit of the offset field
        bcc     @positive               ; Was positive so just leave it
        ora     #$C0                    ; Sign extend to bits 6 and 7
        dex                             ; And to high byte
@positive:
        clc
        adc     pvm_program_ptr         ; Add to pvm_program_ptr
        pha
        txa
        adc     pvm_program_ptr+1
        tax
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

.macro MATCH_RANGE_write start, end
        .byte (end - start) + 1, start
.endmacro

.macro MATCH_RANGE_args r1, r2, r3, r4
    ; Check if the first argument is blank. If it is, we are done with the list: exit.
    .ifblank r1
        .byte 0
        .exitmacro
    .endif

    ; Output the current pair.
    MATCH_RANGE_write r1

    ; Recursively call the macro with the remaining arguments.
    MATCH_RANGE_args {r2}, {r3}, {r4}
.endmacro

.macro MATCH_RANGE r1, r2, r3, r4
        .byte PVM_MATCH_RANGE
        MATCH_RANGE_args {r1}, {r2}, {r3}, {r4}
.endmacro

; Use (* + 1) because we add offset to address after skipping the instruction byte. 

.macro TRY address
        .assert (address - (* + 1)) >= 0 .and (address - *) <= 31, error, "Address offset out of range"
        .byte   PVM_TRY + (<(address - (* + 1)) & $1F)
.endmacro

.macro JUMP address
        .assert (address - (* + 1)) >= -32 .and (address - *) <= 31, error, "Address offset out of range"
        .byte   PVM_JUMP + (<(address - (* + 1)) & $3F)
.endmacro

.macro CALL address
        .assert (address - (* + 1)) >= -32 .and (address - *) <= 31, error, "Address offset out of range"
        .byte   PVM_CALL + (<(address - (* + 1)) & $3F)
.endmacro

.macro FAIL
        .byte   PVM_FAIL
.endmacro

.macro RETURN
        .byte   PVM_RETURN
.endmacro

.macro FAR_JUMP address
        .byte   PVM_FAR_JUMP, <address, >address
.endmacro

.macro FAR_CALL address
        .byte   PVM_FAR_CALL, <address, >address
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





; .macro BEGIN
;         .byte   PVM_BEGIN
; .endmacro

; .macro TOKENIZE address
;         .byte   PVM_TOKENIZE, <address, >address
; .endmacro

; .macro DISPATCH
;         .byte   PVM_DISPATCH
; .endmacro

; .macro EMIT b
;         .byte   PVM_EMIT, b
; .endmacro

; .macro INT
;         .byte   PVM_INT
; .endmacro

; .macro EOL
;         .byte   PVM_EOL
; .endmacro

; .macro LINK
;         .byte   PVM_LINK
; .endmacro

; .macro DISCARD
;         .byte   PVM_DISCARD
; .endmacro

; PVM program

pvm_line:
;         LINK
;         WS
;         TRY @immediate
;         INT
;         ACCEPT @first_statement
; @first_statement:
;         WS
;         TRY @statement
;         EOL
; @done:
;         RETURN
; @statement:
;         CALL pvm_line_statement
;         TRY @done
;         WS
;         MATCH ':'
;         DISCARD
;         ACCEPT @statement
; @immediate:
;         EMIT $FF                        ; Write -1 as line number
;         EMIT $FF
;         JUMP @first_statement

; pvm_line_statement:
;         LINK
;         CALL pvm_statement
;         EMIT 0
;         RETURN

pvm_statement:
;         WS
;         BEGIN
;         CALL pvm_name
;         TOKENIZE statement_name_table
;         DISPATCH

; Argument lists

pvm_arg_2:
        CALL pvm_expression
        ARGSEP
        JUMP pvm_expression

pvm_opt_arg_2:
        TRY @done
        CALL pvm_expression
        ARGSEP
        TRY @fail                       ; Parsed the argument separator so must read another argument
        CALL pvm_expression
@done:
        RETURN
@fail:
        FAIL

; pvm_arg_list is list of 1-N (but not 0) expressions.

pvm_arg_list:
        CALL pvm_expression
        TRY @done
        ARGSEP
        TRY @fail                       ; Parsed the argument separator so must read another argument
        JUMP pvm_arg_list
@done:
        RETURN
@fail:
        FAIL

; Expressions

pvm_expression:
        CALL pvm_primary_expression
        RETURN
;         TRY @done
;         WS
;         BEGIN
;         TRY @not_operator_name
;         CALL pvm_name
;         JUMP @tokenize_operator
; @not_operator_name:
;         MATCH_RANGE '&', '?'
;         TRY @tokenize_operator
;         MATCH_RANGE '<', '>'
; @tokenize_operator:
;         TOKENIZE operator_name_table
;         COMPOSE TOKEN_OP
;         ACCEPT pvm_expression
; @done:
;         RETURN

; pvm_primary_expression does not discard whitespace at the top level.
; Each primary expression alternative discards whitespace.

pvm_primary_expression:
        TRY @variable
        FAR_CALL pvm_number
        RETURN
@variable:
        FAR_CALL pvm_variable
        RETURN

;         TRY @string
;         WS
;         MATCH '('
;         CALL pvm_expression
;         WS
;         MATCH ')'
;         RETURN
; @string:
;         TRY @number
;         CALL pvm_string
;         RETURN
; @number:
;         TRY @unary_operator
;         CALL pvm_number
;         RETURN
; @unary_operator:
;         TRY @function
;         WS
;         BEGIN
;         TRY @not_unary_operator_name
;         CALL pvm_name
;         JUMP @tokenize_unary_operator
; @not_unary_operator_name:
;         BEGIN
;         MATCH '-'
; @tokenize_unary_operator:
;         TOKENIZE unary_operator_name_table
;         COMPOSE TOKEN_UNARY_OP
;         JUMP pvm_primary_expression
; @function:
;         TRY @variable
;         WS
;         BEGIN
;         CALL pvm_name
;         TRY @tokenize_function
;         MATCH '$'
;         ACCEPT @tokenize_function
; @tokenize_function:
;         TOKENIZE function_name_table
;         COMPOSE TOKEN_FUNCTION
;         ACCEPT @function_paren          ; Recognized the function name so arg list is now mandatory
; @function_paren:
;         MATCH '('
;         CALL pvm_arg_list
;         WS
;         MATCH ')'
;         RETURN
; @variable:
;         JUMP pvm_variable

; Low-level rules

; number ::= _ sign? (digit+ ('.' digit*)?) | ('.' digit*)) ('E' sign? digit+)
pvm_number:
        WS
        CALL pvm_number_opt_sign
        CALL pvm_number_body
        CALL pvm_number_opt_e
        RETURN

pvm_number_opt_sign:
        TRY @done
        MATCH '-'
@done:
        RETURN

pvm_number_body:
        TRY pvm_number_decimal_digits
        CALL pvm_digits
        TRY @done
        CALL pvm_number_decimal_digits
@done:
        RETURN

pvm_number_decimal_digits:
        MATCH '.'
        JUMP pvm_opt_digits

pvm_number_opt_e:
        TRY @done
        MATCH 'E'
        CALL pvm_number_opt_sign
        CALL pvm_digits
@done:
        RETURN

; pvm_digits does not remove whitespace.
; It is only used from pvm_number.

pvm_digits:
        MATCH_RANGE {'0', '9'}
pvm_opt_digits:
        TRY @done
        JUMP pvm_digits
@done:
        RETURN

; ; pvm_number_list is list of 1-N (but not 0) numbers.

; pvm_number_list:
;         CALL pvm_number
;         TRY @done
;         ARGSEP
;         ACCEPT pvm_number_list
; @done:
;         RETURN

pvm_string:
        WS
        MATCH '"'
@next:
        TRY @non_quote
        MATCH '"'
        TRY @done
        MATCH '"'
        JUMP @next
@non_quote:
        MATCH *
        JUMP @next
@done:
        RETURN

pvm_variable:
        WS
        CALL pvm_name
        TRY @array_paren
        MATCH '$'
@array_paren:
        COMPOSE EOT
        TRY @done
        MATCH '('
        FAR_CALL pvm_arg_list
        MATCH ')'
@done:
        RETURN


; ; pvm_variable_list is list of 1-N (but not 0) variables.

; pvm_variable_list:
;         CALL pvm_variable
;         TRY @done
;         ARGSEP
;         ACCEPT pvm_variable_list
; @done:
;         RETURN

; ; Captures all text to EOL.

; pvm_text:
;         WS
;         TRY @done
;         MATCH *
;         ACCEPT pvm_text
; @done:
;         RETURN
        
; pvm_name does not discard whitespace.
; Its only job is to capture an alphanumeric "name."

pvm_name:
        MATCH_RANGE {'A', 'Z'}
@next:
        TRY @done
        MATCH_RANGE {'A', 'Z'}, {'0', '9'}, {'_', '_'}
        JUMP @next
@done:
        RETURN

statement_name_table:
        name_table_entry "END"
            RETURN
:       name_table_entry "RUN"
            RETURN
; :       name_table_entry "PRINT"
;             JUMP pvm_expression
; :       name_table_entry "LET"
;             CALL pvm_variable
;             MATCH '='
;             JUMP pvm_expression
; :       name_table_entry "INPUT"
;             JUMP pvm_variable_list
; :       name_table_entry "LIST"
;             JUMP pvm_opt_arg_2
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
;             WS
;             BEGIN
;             MATCH "GO"
;             CALL pvm_name
;             TOKENIZE clause_name_table
;             COMPOSE TOKEN_CLAUSE
;             JUMP pvm_number_list
; :       name_table_entry "FOR"
;             CALL pvm_variable
;             WS
;             MATCH '='
;             CALL pvm_expression
;             WS
;             BEGIN
;             MATCH "TO"
;             TOKENIZE clause_name_table
;             COMPOSE TOKEN_CLAUSE
;             CALL pvm_expression
;             WS
;             TRY @for_done
;             BEGIN
;             MATCH "STEP"
;             ACCEPT @tokenize_step
; @tokenize_step:
;             TOKENIZE clause_name_table
;             COMPOSE TOKEN_CLAUSE
;             JUMP pvm_expression
; @for_done:
;             RETURN
; :       name_table_entry "NEXT"
;             JUMP pvm_variable
; :       name_table_entry "STOP"
;             RETURN
; :       name_table_entry "CONT"
;             RETURN
; :       name_table_entry "IF"
;             CALL pvm_expression
;             WS
;             BEGIN
;             MATCH "THEN"
;             TOKENIZE clause_name_table
;             COMPOSE TOKEN_CLAUSE
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
;             JUMP pvm_arg_2
; :       name_table_end

clause_name_table:
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
