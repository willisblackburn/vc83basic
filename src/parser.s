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

parse_line:
        mva     #0, buffer_pos                  ; Initialize the read pointer
        mva     #.sizeof(Line) + 1, line_pos    ; Initialize write pointer (leave room for statement length byte)
        mvax    #buffer, read_ptr       ; Set up read_ptr so parsing primitives work
        ldy     buffer_pos
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
        ldpha   line_pos                ; Save start of statement position
        jsr     parse_statement
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
        bne     syntax_error            ; Nope, fail
        rts

@check_separator:
        cmp     #TOK_COLON              ; Otherwise it had better be a statement separator
        beq     @next_statement         ; It was ':'

syntax_error:
        raise   ERR_SYNTAX_ERROR

; --- Helpers ---

; Reads next token and verifies it matches expected token.
; A = expected token on entry.
; On mismatch, raises syntax error.

require_token:
        sta     D                       ; Save expected token
        jsr     next_token              ; Read next token
        cmp     D                       ; Compare with expected
        bne     syntax_error            ; Mismatch -> error
        rts

; Reads next token speculatively, saving buffer_pos and line_pos in D/E.
; Returns token in A.

read_ahead:
        mva     buffer_pos, D           ; Save read position
        mva     line_pos, E             ; Save write position
        jmp     next_token              ; Read and return token in A

; Restores buffer_pos and line_pos from D/E, undoing a speculative read.

reject_token:
        mva     D, buffer_pos           ; Restore read position
        mva     E, line_pos             ; Restore write position
        rts

; --- Statement dispatch ---

; Tokens $40-$51 are dispatched via parse_stmt_table.
; Tokens $52-$7F are no-arg statements (just return).
; TOK_NAME ($13) triggers implicit LET.

parse_statement:
        jsr     next_token              ; Read statement keyword
        cmp     #TOK_NAME               ; Implicit LET?
        beq     parse_impl_let
        sec
        sbc     #TOK_PRINT              ; A = token - $40
        cmp     #TOK_RESTORE - TOK_PRINT + 1 ; In table range? ($40-$51)
        bcc     @dispatch
        cmp     #TOK_RUN - TOK_PRINT    ; No-arg range starts at $52
        bcc     @syntax_err
        cmp     #$80 - TOK_PRINT        ; No-arg range ends at $7F
        bcc     @done
@syntax_err:
        jmp     syntax_error

@dispatch:
        asl     A                       ; Multiply by 2 for table offset
        tax
        lda     parse_stmt_table+1,x    ; High byte of handler
        pha
        lda     parse_stmt_table,x      ; Low byte of handler
        pha
@done:
        rts                             ; Jump to handler (or return for no-arg)

parse_stmt_table:
        .word   parse_print-1           ; $40 PRINT
        .word   parse_print-1           ; $41 ALT_PRINT
        .word   parse_let-1             ; $42 LET
        .word   parse_for-1             ; $43 FOR
        .word   parse_next_stmt-1       ; $44 NEXT
        .word   parse_if-1              ; $45 IF
        .word   parse_input-1           ; $46 INPUT
        .word   parse_read-1            ; $47 READ
        .word   parse_on-1              ; $48 ON
        .word   parse_goto_gosub-1      ; $49 GOTO
        .word   parse_goto_gosub-1      ; $4A GOSUB
        .word   parse_list-1            ; $4B LIST
        .word   parse_arg_2-1           ; $4C POKE
        .word   parse_arg_2-1           ; $4D DPOKE
        .word   parse_dim-1             ; $4E DIM
        .word   parse_data_rem-1        ; $4F DATA
        .word   parse_data_rem-1        ; $50 REM
        .word   parse_restore-1         ; $51 RESTORE

; --- Simple statement entry points ---

parse_let:
        lda     #TOK_NAME               ; LET requires variable name
        jsr     require_token

parse_impl_let:
        jsr     parse_optional_array    ; Optional array subscript
        lda     #TOK_EQ
        jsr     require_token           ; Require '='
        jmp     parse_expression        ; Parse the value

parse_next_stmt:
        lda     #TOK_NAME               ; NEXT requires variable name
        jmp     require_token

parse_goto_gosub:
        lda     #TOK_NUM                ; GOTO/GOSUB require line number
        jmp     require_token

; --- Statement parsers ---

; PRINT [sep|expr] [sep [expr]] ...
; sep = SEMI | COMMA
; Terminates on COLON, EOL

parse_print:
@check:
        jsr     read_ahead              ; Speculatively read next token
        cmp     #TOK_SEMI               ; Leading/trailing separator?
        beq     @check
        cmp     #TOK_COMMA
        beq     @check
        cmp     #TOK_COLON              ; End of statement?
        beq     @guard
        tax                             ; Check for EOL (= 0)
        beq     @guard
        jsr     reject_token            ; Not separator/end: must be expression
        jsr     parse_expression

; After expression, must see separator or end

        jsr     read_ahead
        cmp     #TOK_SEMI
        beq     @check
        cmp     #TOK_COMMA
        beq     @check
        cmp     #TOK_COLON
        beq     @guard
        tax
        beq     @guard                  ; EOL
        jmp     syntax_error            ; Unexpected token after expression

@guard:
        jmp     reject_token            ; Un-read terminator and return

; FOR variable = start TO end [STEP step]

parse_for:
        lda     #TOK_NAME               ; Variable name
        jsr     require_token
        lda     #TOK_EQ                 ; '='
        jsr     require_token
        jsr     parse_expression        ; Start value
        lda     #TOK_TO                 ; 'TO'
        jsr     require_token
        jsr     parse_expression        ; End value
        jsr     read_ahead              ; Check for optional STEP
        cmp     #TOK_STEP
        beq     @step
        jmp     reject_token            ; No STEP; un-read token and return

@step:
        jmp     parse_expression        ; Parse step value (tail call)

; IF expression THEN line_number | statement

parse_if:
        jsr     parse_expression        ; Condition
        lda     #TOK_THEN               ; 'THEN'
        jsr     require_token
        jsr     read_ahead              ; Check if followed by line number
        cmp     #TOK_NUM
        beq     @line_number            ; Line number: already consumed, done
        jsr     reject_token            ; Otherwise parse a statement
        jmp     parse_statement

@line_number:
        rts

; INPUT [string ;] var [, var] ...

parse_input:
        jsr     read_ahead              ; Check for optional prompt string
        cmp     #TOK_STRING
        beq     @prompt
        jsr     reject_token            ; No prompt; parse variable list
        jmp     parse_read

@prompt:
        lda     #TOK_SEMI               ; Prompt followed by ';'
        jsr     require_token

; READ var [, var] ... (also used by INPUT after prompt)

parse_read:
        lda     #TOK_NAME               ; Variable name
        jsr     require_token
        jsr     parse_optional_array    ; Optional subscript
        jsr     read_ahead              ; Check for more variables
        cmp     #TOK_COMMA
        beq     parse_read              ; Comma: loop for next variable
        jmp     reject_token            ; Done; un-read token

; ON expression GOTO|GOSUB num [, num] ...

parse_on:
        jsr     parse_expression        ; The selector expression
        jsr     next_token              ; Must be GOTO or GOSUB
        cmp     #TOK_GOTO
        beq     @line_list
        cmp     #TOK_GOSUB
        beq     @line_list
        jmp     syntax_error

@line_list:
        lda     #TOK_NUM                ; Require line number
        jsr     require_token
        jsr     read_ahead              ; Check for more numbers
        cmp     #TOK_COMMA
        beq     @line_list              ; Comma: loop for next number
        jmp     reject_token            ; Done

; LIST [expr [, expr]]

parse_list:
        jsr     read_ahead              ; Check for empty LIST
        cmp     #TOK_COLON              ; End of statement?
        beq     @guard
        tax
        beq     @guard                  ; EOL?
        jsr     reject_token            ; Has arguments
        jsr     parse_expression        ; First argument
        jsr     read_ahead              ; Check for second argument
        cmp     #TOK_COMMA
        bne     @guard                  ; No comma: un-read and return
        jmp     parse_expression        ; Second argument (tail call)

@guard:
        jmp     reject_token

; RESTORE [line_number]

parse_restore:
        jsr     read_ahead              ; Check for optional line number
        cmp     #TOK_NUM
        beq     @done                   ; Number consumed; return
        jmp     reject_token            ; No number; un-read and return

@done:
        rts

; DIM name[(subscripts)] [, ...]

parse_dim:
        lda     #TOK_NAME               ; Variable name
        jsr     require_token
        jsr     parse_optional_array    ; Optional subscript
        jsr     read_ahead              ; Check for more dimensions
        cmp     #TOK_COMMA
        beq     parse_dim               ; Comma: loop
        jmp     reject_token            ; Done

; DATA text / REM text
; Copies remaining raw characters into line_buffer, skipping leading whitespace.

parse_data_rem:
        ldx     buffer_pos
@skip_ws:
        lda     buffer,x                ; Read character
        beq     @slurp_done             ; End of line
        cmp     #' '                    ; Skip spaces
        bne     @copy
        inx
        bne     @skip_ws

@copy:
        lda     buffer,x                ; Read character
        beq     @slurp_done             ; End of line
        jsr     append_line_buffer      ; Append to output
        inx
        bne     @copy

@slurp_done:
        stx     buffer_pos              ; Update read position
        rts

; --- Expression parser ---

; expression = primary_expression [operator expression]

parse_expression:
        jsr     parse_primary_expression
        jsr     read_ahead              ; Check for operator
        and     #$F0                    ; Isolate token class
        cmp     #TOK_CLASS_OP_2X        ; Operator class?
        beq     parse_expression        ; Yes: consume operator and recurse
        jmp     reject_token            ; No: un-read and return

; primary_expression = num | string | name[()] | function() | (expr) | unary primary

parse_primary_expression:
        jsr     next_token              ; Read primary token
        cmp     #TOK_LPAREN             ; Subexpression?
        beq     @subexpr
        cmp     #TOK_ADD                ; Unary +?
        beq     parse_primary_expression
        cmp     #TOK_SUB                ; Unary -?
        beq     parse_primary_expression
        cmp     #TOK_NOT                ; Unary NOT?
        beq     parse_primary_expression
        cmp     #TOK_NUM                ; Number literal?
        beq     @done
        cmp     #TOK_STRING             ; String literal?
        beq     @done
        cmp     #TOK_NAME               ; Variable name?
        beq     @name
        cmp     #$80                    ; Function tokens are $80-$BF
        bcc     @fail
        cmp     #$C0
        bcc     @function
@fail:
        jmp     syntax_error

@done:
        rts

@subexpr:
        jsr     parse_expression        ; Parse inner expression
        lda     #TOK_RPAREN             ; Require ')'
        jmp     require_token

@name:
        jmp     parse_optional_array    ; Check for subscript

@function:
        jmp     parse_function

; name [(arg_list)]

parse_optional_array:
        jsr     read_ahead              ; Check for '('
        cmp     #TOK_LPAREN
        beq     @array
        jmp     reject_token            ; No '('; un-read and return

@array:
        jsr     parse_arg_list          ; Parse subscripts
        lda     #TOK_RPAREN             ; Require ')'
        jmp     require_token

; function (arg_list) | function ()

parse_function:
        lda     #TOK_LPAREN             ; Require '('
        jsr     require_token
        jsr     read_ahead              ; Check for empty args
        cmp     #TOK_RPAREN
        beq     @empty                  ; Already consumed ')'; done
        jsr     reject_token            ; Has arguments
        jsr     parse_arg_list
        lda     #TOK_RPAREN             ; Require ')'
        jmp     require_token

@empty:
        rts

; --- Argument lists ---

; Two arguments separated by comma (used by POKE, DPOKE)

parse_arg_2:
        jsr     parse_expression        ; First argument
        lda     #TOK_COMMA              ; Require ','
        jsr     require_token
        jmp     parse_expression        ; Second argument (tail call)

; Variable-length argument list: expr [, expr] ...

parse_arg_list:
        jsr     parse_expression        ; First argument
        jsr     read_ahead              ; Check for more
        cmp     #TOK_COMMA
        beq     parse_arg_list          ; Comma: loop for next
        jmp     reject_token            ; Done; un-read token
