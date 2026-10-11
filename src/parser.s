; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

.segment "PARSER"

; All "parse" functions use:
; buffer = the buffer containing the user-entered program source
; buffer_pos = the read position in buffer (modified on success)
; line_buffer = the buffer containing the tokenized output
; line_pos = the token write position in line_buffer (modified on success)

; Parses a line from the buffer. The line is an optional line number followed by statements.
; If the line number is missing, set it to -1.
; Returns normally if buffer was a valid program line, or raises an exception.

.assert TOK_EOL = 0, error

; We assume that RETURN is the first of a list of unparameterized opcodes in the range $F0-$FF.
.assert PVM_RETURN = $F0, error

parse_line:
        lda     #0
        sta     buffer_pos                      ; Initialize the read pointer
        tay
        mva     #.sizeof(Line) + 1, line_pos    ; Initialize write pointer (leave room for statement length byte)
        mvax    #buffer, read_ptr               ; Set up read_ptr so parsing primitives work
        jsr     string_to_fp_2                  ; Parse line number
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
        sty     buffer_pos
        beq     @finish_line            ; Was zero

; Parse one statement. The statement must be found because the line is not blank and this is either the first

; statement or we just parsed a ':'.

@next_statement:
        ldpha   line_pos                ; Save start of statement position
        ldax    #pvm_statement
        jsr     parse_pvm
        lda     #TOK_EOL                ; Store TOK_EOL at end of statement
        jsr     append_line_buffer
        pla                             ; Get back the start of statement
        tax                             
        tya                             ; Current write position is next statement offset
        sta     line_buffer-1,x         ; Write it to the byte before the start of this statement
        jsr     next_token              ; Read the next token
        bne     @check_separator        ; Z still be set if the next token is EOL

@finish_line:
        mva     line_pos, line_buffer+Line::next_line_offset    ; Write position is next line offset
        ldx     buffer_pos
        lda     buffer,x                ; Verify the line ends with 0 as expected
        bne     raise_syntax_error      ; Nope, fail
        rts

@check_separator:
        cmp     #TOK_COLON              ; Otherwise it had better be a statement separator
        beq     @next_statement         ; It was ':'

raise_syntax_error:
        raise   ERR_SYNTAX_ERROR

; Invokes parsing virtual machine (PVM).
; AX = address of first PVM opcode
; buffer_pos = where to read from buffer
; line_pos = where to write to line_buffer

parse_pvm:
        stax    pvm_program_ptr
        jsr     run_pvm_next_token
        bcs     raise_syntax_error
        mva     D, buffer_pos           ; Put back the last token that was read but not matched
        mva     E, line_pos
        rts

; Resume processing opcodes.
; Returns carry clear if the parse succeeded, or carry set if it failed.
; Returns with pvm_program_ptr pointing to the opcode after the the one that caused run_pvm to exit,
; and the last opcode in B.

run_pvm_next_token:
        mva     buffer_pos, D           ; Save state so we can put back the last token
        mva     line_pos, E
        jsr     next_token              ; Clobbers BC, but we can use after
        sta     C                       ; Hold the token we just read in C
run_pvm:
        jsr     get_next_pvm_byte       ; Load PVM opcode

; Handle the opcode

        cmp     #PVM_CALL
        bcc     @match
        cmp     #PVM_JUMP
        bcc     @call
        cmp     #PVM_BRANCH_IF
        bcc     @jump
        cmp     #PVM_RETURN
        bcc     @branch_if
        clc                             ; If it was RETURN, make sure the carry is clear
        beq     @return
        cmp     #PVM_GUARD
        beq     @guard
        cmp     #PVM_SLURP
        beq     @slurp                  ; Anything else falls through with C=1 (PVM_FAIL)
@return:
        rts

@match:
        jsr     match_token
        beq     run_pvm_next_token      ; It matched; continue
@fail:
        sec                             ; Set carry to indicate failure and return
        rts

@call:
        jsr     calculate_address_10    ; Get the address: pvm_program_ptr is return address, call address in AX
        tay
        ldphaa  pvm_program_ptr         ; Save the return address
        sty     pvm_program_ptr
        stx     pvm_program_ptr+1       ; Save new address
        jsr     run_pvm                 ; Call it
        plstaa  pvm_program_ptr         ; Recover return address
        bcs     @fail                   ; If the called function failed then just keep failing
        jmp     run_pvm

@jump:
        jsr     calculate_address_10    ; Get the address: call address in AX
        stax    pvm_program_ptr
        jmp     run_pvm

@branch_if:
        jsr     calculate_address_10    ; Get the address: call address in AX
        stax    vector_ptr
        jsr     get_next_pvm_byte       ; A is the byte we have to match
        jsr     match_token             ; Try to match it
        bne     run_pvm                 ; If it didn't match then just carry on
        mvax    vector_ptr, pvm_program_ptr     ; Continue at the branch address
        bne     run_pvm_next_token      ; Unconditional

@guard:
        jsr     get_next_pvm_byte       ; Read the token we want to match
        jsr     match_token
        bne     run_pvm                 ; If it didn't match then just carry on with the next instruction
        clc                             ; Else the guard stops this function and causes it to return success
        rts

@slurp:
        ldx     D                       ; Read from D (buffer_pos before speculative next_token)
        ldy     E                       ; Write to line_pos before speculative next_token
        sty     line_pos
@slurp_whitespace:
        lda     buffer,x
        beq     @done
        cmp     #' '
        bne     @slurp_next
        inx
        bne     @slurp_whitespace
@slurp_next:             
        lda     buffer,x
        beq     @done
        jsr     append_line_buffer
        inx
        bne     @slurp_next
@done:
        stx     D
        sty     E
        clc                             ; There can't be anything more to parse so return success
        rts

; Matches the token in C with the opcode.
; A = the opcode
; Z flag will indicate whether it was matched or not
; DE SAFE

match_token:
        cmp     #PVM_MATCH_RANGE        ; Opcodes below this are exact token matches
        bcc     @exact_match
        and     #$0F                    ; Extract limit (count - 1)
        sta     B                       ; Save limit in B
        jsr     get_next_pvm_byte       ; A = min_token
        eor     #$FF                    ; Compute A = C - min_token; A = ~min_token
        adc     C                       ; A = C (guaranteed set) + ~min_token + 1 (which is C - min_token)
        cmp     B                       ; Compare difference with limit
        beq     @match                  ; A = limit -> match
        bcc     @match                  ; A < limit -> match
        rts                             ; No match: return with Z flag clear

@match:
        lda     C                       ; Force the compare to return equality

@exact_match:
        cmp     C                       ; Compare opcode, now the token we need to match, to the next token
        rts

; Gets the next byte from the PVM program and returns it in A.
; Increments pvm_program_ptr.
; X SAFE, BC SAFE, DE SAFE

get_next_pvm_byte:
        ldy     #0
        lda     (pvm_program_ptr),y     ; Load PVM opcode
        inc     pvm_program_ptr
        bne     @skip_inc
        inc     pvm_program_ptr+1
@skip_inc:
        rts

; Calculates the address of JUMP or CALL using 2 bits from the opcode plus the next byte, for 10 bits total.
; A = the opcode
; Return the new pvm_program_ptr value in AX

calculate_address_10:
        and     #$03                    ; Ignore top four bits of opcode
        cmp     #$02                    ; Test bit 1, which is the sign bit of the offset field
        bcc     @positive               ; Was positive so just leave it
        ora     #$FC                    ; Sign extend to high nybble
@positive:
        tax                             ; Save high byte
        jsr     get_next_pvm_byte  
        clc
        adc     pvm_program_ptr         ; Add to pvm_program_ptr
        pha
        txa
        adc     pvm_program_ptr+1
        tax
        pla
        rts

; PVM macros

.macro MATCH t
        .assert t < $C0, error, "Can only match tokens not opcodes"
        .byte t    
.endmacro

.macro MATCH_RANGE min_token, count
        .assert count >= 1 .and count <= 16, error, "Range count must be 1..16"
        .byte PVM_MATCH_RANGE | (count - 1), min_token
.endmacro

.macro write_opcode_address opcode, address
        .assert (address - (* + 2)) >= -512 .and (address - (* + 2)) <= 511, error, "Address offset out of range"
        .byte   opcode | >(address - (* + 2)) & $03, <(address - (* + 1))
.endmacro

.macro CALL address
        write_opcode_address PVM_CALL, address
.endmacro

.macro JUMP address
        write_opcode_address PVM_JUMP, address
.endmacro

.macro BRANCH_IF t, address
        write_opcode_address PVM_BRANCH_IF, address
        MATCH t
.endmacro

.macro BRANCH_IF_RANGE min_token, count, address
        write_opcode_address PVM_BRANCH_IF, address
        MATCH_RANGE min_token, count
.endmacro

.macro RETURN
        .byte PVM_RETURN
.endmacro

.macro FAIL
        .byte PVM_FAIL
.endmacro

.macro GUARD t
        .byte PVM_GUARD
        MATCH t
.endmacro

.macro GUARD_RANGE min_token, count
        .byte PVM_GUARD
        MATCH_RANGE min_token, count
.endmacro

.macro SLURP
        .byte PVM_SLURP
.endmacro

; PVM program

pvm_statement:
        BRANCH_IF TOK_PRINT, pvm_print
        BRANCH_IF TOK_ALT_PRINT, pvm_print
        BRANCH_IF TOK_LET, pvm_let
        BRANCH_IF TOK_NAME, pvm_impl_let
        BRANCH_IF TOK_FOR, pvm_for
        BRANCH_IF TOK_NEXT, pvm_next
        BRANCH_IF TOK_IF, pvm_if
        BRANCH_IF TOK_INPUT, pvm_input
        BRANCH_IF TOK_READ, pvm_read
        BRANCH_IF TOK_ON, pvm_on
        BRANCH_IF TOK_GOTO, pvm_goto
        BRANCH_IF TOK_GOSUB, pvm_gosub
        BRANCH_IF TOK_LIST, pvm_list
        BRANCH_IF TOK_POKE, pvm_arg_2
        BRANCH_IF TOK_DPOKE, pvm_arg_2
        BRANCH_IF TOK_DIM, pvm_read
        BRANCH_IF TOK_DATA, pvm_data
        BRANCH_IF TOK_REM, pvm_rem
        BRANCH_IF TOK_RESTORE, pvm_restore
        BRANCH_IF_RANGE TOK_RUN, 8, @done       ; Any other no-arg statement (RUN..POP, $52..$59)
        BRANCH_IF TOK_GET, pvm_get
        BRANCH_IF TOK_PUT, pvm_put
        BRANCH_IF TOK_SAVE, pvm_save_load
        BRANCH_IF TOK_LOAD, pvm_save_load
        invoke_if_defined extension_pvm_statements
        FAIL
@done:
        RETURN

; Statements

.ifdef enable_io_channels
pvm_channel:
        BRANCH_IF_RANGE TOK_CHANNEL_0, 8, @done
@done:
        RETURN
.endif

pvm_get:
.ifdef enable_io_channels
        CALL pvm_channel
.endif
        MATCH TOK_NAME
        JUMP pvm_optional_array

pvm_put:
.ifdef enable_io_channels
        CALL pvm_channel
.endif
        JUMP pvm_expression

pvm_save_load:
        JUMP pvm_expression

pvm_print:
.ifdef enable_io_channels
        CALL pvm_channel
.endif
@loop:
        BRANCH_IF TOK_SEMI, @loop
        BRANCH_IF TOK_COMMA, @loop
        GUARD TOK_COLON                 ; Abandon the PRINT statement if we see COLON or EOL
        GUARD TOK_EOL
        CALL pvm_expression             ; Otherwise it has to be an expression
        BRANCH_IF TOK_SEMI, @loop
        BRANCH_IF TOK_COMMA, @loop
        GUARD TOK_COLON
        GUARD TOK_EOL
        FAIL

pvm_let:
        MATCH TOK_NAME
pvm_impl_let:
        CALL pvm_optional_array
        MATCH TOK_EQ
        JUMP pvm_expression

pvm_for:
        MATCH TOK_NAME
        MATCH TOK_EQ
        CALL pvm_expression
        MATCH TOK_TO
        CALL pvm_expression
        BRANCH_IF TOK_STEP, pvm_expression
        RETURN

pvm_next:
        MATCH TOK_NAME
        RETURN

pvm_if:
        CALL pvm_expression
        MATCH TOK_THEN
        BRANCH_IF TOK_NUM, @done
        JUMP pvm_statement
@done:
        RETURN

pvm_input:
.ifdef enable_io_channels
        CALL pvm_channel
.endif
        BRANCH_IF TOK_STRING, @prompt
        JUMP pvm_read
@prompt:
        MATCH TOK_SEMI

pvm_read:
        MATCH TOK_NAME
        CALL pvm_optional_array
        BRANCH_IF TOK_COMMA, pvm_read
        RETURN

pvm_on:
        CALL pvm_expression
        BRANCH_IF TOK_GOTO, @line_number_list
        BRANCH_IF TOK_GOSUB, @line_number_list
        FAIL

@line_number_list:
        MATCH TOK_NUM
        BRANCH_IF TOK_COMMA, @line_number_list
        RETURN

pvm_goto:
pvm_gosub:
        MATCH TOK_NUM
        RETURN

pvm_list:
        GUARD TOK_COLON
        GUARD TOK_EOL
        CALL pvm_expression
        BRANCH_IF TOK_COMMA, pvm_expression
@done:
        RETURN

pvm_restore:
        BRANCH_IF TOK_NUM, @done
@done:
        RETURN

pvm_data:
pvm_rem:
        SLURP

; Expressions

pvm_expression:
        CALL pvm_primary_expression
        BRANCH_IF_RANGE TOK_ADD, 14, pvm_expression
        RETURN

pvm_primary_expression:
        BRANCH_IF TOK_LPAREN, pvm_subexpression
        BRANCH_IF TOK_ADD, pvm_primary_expression   ; Unary +
        BRANCH_IF TOK_SUB, pvm_primary_expression   ; Unary -
        BRANCH_IF TOK_NOT, pvm_primary_expression   ; Unary NOT
        BRANCH_IF TOK_NAME, pvm_optional_array
        BRANCH_IF_RANGE TOK_LEN, 15, pvm_fun_1      ; 1-arg functions ($80..$8E: LEN..RND)
        BRANCH_IF TOK_LEFT_S, pvm_fun_2             ; 2-arg function ($8F: LEFT$)
        BRANCH_IF_RANGE TOK_RIGHT_S, 2, pvm_fun_2   ; 2-arg functions ($90..$91: RIGHT$, USR)
        BRANCH_IF TOK_MID_S, pvm_fun_3              ; 3-arg function ($92: MID$)
        BRANCH_IF_RANGE TOK_FRE, 2, pvm_fun_0       ; 0-arg functions ($93..$94: FRE, INKEY$)
.ifdef enable_trig_functions
        BRANCH_IF_RANGE TOK_SIN, 4, pvm_fun_1       ; 1-arg functions ($95..$98: SIN..ATN)
.endif
        invoke_if_defined extension_pvm_functions
        BRANCH_IF TOK_NUM, @done
        MATCH TOK_STRING
@done:
        RETURN

pvm_subexpression:
        CALL pvm_expression
        MATCH TOK_RPAREN
        RETURN

pvm_optional_array:
        BRANCH_IF TOK_LPAREN, @array
        RETURN

@array:
        CALL pvm_arg_list
        MATCH TOK_RPAREN
        RETURN

pvm_fun_0:
        MATCH TOK_LPAREN
pvm_close_paren:
        MATCH TOK_RPAREN
        RETURN

pvm_fun_1:
        MATCH TOK_LPAREN
        CALL pvm_expression
        MATCH TOK_RPAREN
        RETURN

pvm_fun_2:
        MATCH TOK_LPAREN
        CALL pvm_arg_2
        MATCH TOK_RPAREN
        RETURN

pvm_fun_3:
        MATCH TOK_LPAREN
        CALL pvm_arg_3
        MATCH TOK_RPAREN
        RETURN

; Argument lists

pvm_arg_3:
        CALL pvm_expression
        MATCH TOK_COMMA
pvm_arg_2:
        CALL pvm_expression
        MATCH TOK_COMMA
        JUMP pvm_expression

pvm_arg_list:
        CALL pvm_expression
        BRANCH_IF TOK_COMMA, pvm_arg_list
        RETURN

        invoke_if_defined extension_pvm_code
