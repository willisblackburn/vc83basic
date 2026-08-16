; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

.include "lexer_data.inc"

.segment "LEXER"

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

keyword_counter .set 0

.macro name_table_entry s
        .byte   :+ - *
        name s
        keyword_counter .set keyword_counter + 1
.endmacro

.macro name_table_end
        .byte   0
.endmacro

keywords:
; Block 0 ($00..$09)
KEYWORD_BLOCK_0_OFFSET = keyword_counter
        name_table_entry ""             ; Index 0: placeholder for TOK_EOL ($00)
:       name_table_entry ","
:       name_table_entry ";"
:       name_table_entry "("
:       name_table_entry ")"
:       name_table_entry "NOT"
:       name_table_entry "THEN"
:       name_table_entry "TO"
:       name_table_entry "STEP"
:       name_table_entry ":"
; Block 1 ($10..$1F) - unused
KEYWORD_BLOCK_1_OFFSET = keyword_counter
; Block 2 ($20..$2D)
KEYWORD_BLOCK_2_OFFSET = keyword_counter
:       name_table_entry "+"
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
; Block 3 ($30..$3F) - unused
KEYWORD_BLOCK_3_OFFSET = keyword_counter
; Block 4 ($40..$4F)
KEYWORD_BLOCK_4_OFFSET = keyword_counter
:       name_table_entry "PRINT"
:       name_table_entry "?"
:       name_table_entry "LET"
:       name_table_entry "FOR"
:       name_table_entry "NEXT"
:       name_table_entry "IF"
:       name_table_entry "INPUT"
:       name_table_entry "READ"
:       name_table_entry "ON"
:       name_table_entry "GOTO"
:       name_table_entry "GOSUB"
:       name_table_entry "LIST"
:       name_table_entry "POKE"
:       name_table_entry "DPOKE"
:       name_table_entry "DIM"
:       name_table_entry "DATA"
; Block 5 ($50..$5A)
KEYWORD_BLOCK_5_OFFSET = keyword_counter
:       name_table_entry "REM"
:       name_table_entry "RESTORE"
:       name_table_entry "RUN"
:       name_table_entry "STOP"
:       name_table_entry "END"
:       name_table_entry "CONT"
:       name_table_entry "NEW"
:       name_table_entry "CLR"
:       name_table_entry "RETURN"
:       name_table_entry "POP"
.ifdef TARGET_SIM6502
:       name_table_entry "BYE"
.endif
; Block 6 ($60..$6F) - unused
KEYWORD_BLOCK_6_OFFSET = keyword_counter
; Block 7 ($70..$7F) - unused
KEYWORD_BLOCK_7_OFFSET = keyword_counter
; Block 8 ($80..$8F)
KEYWORD_BLOCK_8_OFFSET = keyword_counter
:       name_table_entry "LEN"
:       name_table_entry "STR$"
:       name_table_entry "CHR$"
:       name_table_entry "ASC"
:       name_table_entry "LEFT$"
:       name_table_entry "RIGHT$"
:       name_table_entry "MID$"
:       name_table_entry "VAL"
:       name_table_entry "FRE"
:       name_table_entry "PEEK"
:       name_table_entry "DPEEK"
:       name_table_entry "ADR"
:       name_table_entry "USR"
:       name_table_entry "INT"
:       name_table_entry "LOG"
:       name_table_entry "EXP"
; Block 9 ($90..$98)
KEYWORD_BLOCK_9_OFFSET = keyword_counter
:       name_table_entry "SIN"
:       name_table_entry "COS"
:       name_table_entry "TAN"
:       name_table_entry "ATN"
:       name_table_entry "ABS"
:       name_table_entry "SGN"
:       name_table_entry "SQR"
:       name_table_entry "RND"
.ifdef TARGET_SIM6502
:       name_table_entry "VER$"
.endif
:       name_table_end
; Block A ($A0..$AF) - unused
KEYWORD_BLOCK_A_OFFSET = keyword_counter
; Block B ($B0..$BF) - unused
KEYWORD_BLOCK_B_OFFSET = keyword_counter

keyword_block_offsets:
        .byte   KEYWORD_BLOCK_0_OFFSET  ; $0x: Delimiters ($00..$09)
        .byte   KEYWORD_BLOCK_1_OFFSET  ; $1x: (unused)
        .byte   KEYWORD_BLOCK_2_OFFSET  ; $2x: Operators ($20..$2D)
        .byte   KEYWORD_BLOCK_3_OFFSET  ; $3x: (unused)
        .byte   KEYWORD_BLOCK_4_OFFSET  ; $4x: Statements 1 ($40..$4F)
        .byte   KEYWORD_BLOCK_5_OFFSET  ; $5x: Statements 2 ($50..$59 / $5A)
        .byte   KEYWORD_BLOCK_6_OFFSET  ; $6x: (unused)
        .byte   KEYWORD_BLOCK_7_OFFSET  ; $7x: (unused)
        .byte   KEYWORD_BLOCK_8_OFFSET  ; $8x: Functions 1 ($80..$8F)
        .byte   KEYWORD_BLOCK_9_OFFSET  ; $9x: Functions 2 ($90..$98)
        .byte   KEYWORD_BLOCK_A_OFFSET  ; $Ax: (unused)
        .byte   KEYWORD_BLOCK_B_OFFSET  ; $Bx: (unused)



; Parses the next token from buffer using the DFA data tables in lexer_data.inc.
; Writes token characters or matched token byte into line_buffer.
; Reads using X (buffer_pos) and writes using Y (line_pos).
; Skips leading whitespace. Returns the next token in line_buffer at position line_pos, then the
; token value in the following positions. Updates line_pos.
; Returns the next token in A.
; DE SAFE

; Buffers must be page-aligned.
.assert <buffer = 0, error
.assert <line_buffer = 0, error

; Appends A to line_buffer and advances line_pos.
; Checks against MAX_LINE_LENGTH and raises ERR_LINE_TOO_LONG if exceeded.

append_line_buffer:
        ldy     line_pos
        cpy     #MAX_LINE_LENGTH
        bcs     @line_too_long
        sta     line_buffer,y
        iny
        sty     line_pos
        rts

@line_too_long:
        raise   ERR_LINE_TOO_LONG

next_token:
        ldx     buffer_pos
        dex                             ; Negate initial inx

@whitespace:
        inx
        lda     buffer,x                ; Load next character
        bne     @not_at_eol             ; Idempotent return if EOL reached
        rts

@not_at_eol:
        cmp     #' '                    ; Space?
        beq     @whitespace             ; Skip space

@init_dfa:
        jsr     append_line_buffer      ; Advance line_pos for token type byte
        sty     decode_name_ptr         ; Start of token value in decode_name_ptr
        lda     #>line_buffer           
        sta     decode_name_ptr+1       ; High byte
        mva     #0, B                   ; B = current DFA state byte offset (relative to state_0)

@dfa_loop:
        ldy     B                       ; Y = state byte offset
        lda     state_0,y               ; Read terminal token tag at offset 0
        cmp     #$80                    ; Carry = 1 if bit 7 (case fold flag) set, else 0
        and     #$7F                    ; Forget the case fold flag
        sta     C                       ; Will need the terminal token without the case fold flag later
        lda     buffer,x                ; Read input character
        bcc     @char_ready             ; Carry clear -> no case folding needed
        cmp     #'a'
        bcc     @char_ready
        cmp     #'z'+1
        bcs     @char_ready
        and     #$DF                    ; Convert 'a'..'z' -> 'A'..'Z'
@char_ready:
        pha                             ; Save the character on the stack
        iny                             ; Y = state + 1 (transition count offset)
        lda     state_0,y               ; Read transition count
        beq     @finish_token           ; 0 transitions -> finish token matching
        sta     B                       ; Re-use B for counting down the number of transitions
        iny                             ; Y = state + 2 (first min_char offset)
@check_range:
        pla                             ; Read character from D
        pha                             ; Keep it on the stack
        sec
        sbc     state_0,y               ; A = char - min_char
        iny                             ; Y points to count_chars
        cmp     state_0,y               ; Compare (char - min_char) to count_chars
        bcs     @out_of_range           ; Carry set -> not in range [0, count-1]
        iny                             ; Y points to target_state byte offset
        lda     state_0,y
        sta     B                       ; B is once again the state byte offset relative to state_0
        pla                             ; Read character from stack
        jsr     append_line_buffer      ; Store in line_buffer
        inx
        bne     @dfa_loop               ; Unconditional

@out_of_range:
        iny                             ; Skip dest_state
        iny                             ; Point to next min_char
        dec     B                       ; Decrement number of remaining transition records
        bne     @check_range            ; If more than check them, else @finish_token

@finish_token:
        pla                             ; Don't need the character on the stack anymore
        stx     buffer_pos        
        ldy     line_pos                ; Always safe to set EOT bit on last character written
        lda     line_buffer-1,y         ; It will either be necessary (names, numbers),
        ora     #EOT                    ;     overwritten (single-character tokens), or discarded (strings)
        sta     line_buffer-1,y
        lda     C                       ; Read back the terminal token we saved earlier
        ldy     decode_name_ptr         ; Get the line_pos+1 value we saved earlier
        sta     line_buffer-1,y         ; Save the terminal token into the position we reserved for it

; When we entered this function, line_pos was L. Now we have set up:
;     L   = the matched token
;     L+1 = the first character of the token value (decode_name_ptr points here)
;     ...
;     L+n = the last character of the token value, with EOT bit set
; Note that n may be zero, if the first character didn't match anything in state 0; token will be NON_TERMINAL.
; Now we adjust the token and/or value encoding based on the token type.
; If SYMBOL or NAME, try to map the token value to a keyword. If matched, replace token at L with the keyword
; token and discard the value. Otherwise, just return the original toke and the full value.
; If NUM, everything is already formatted correctly, so just return.
; If STRING, the character at L+1 is a quote; replace it with the length byte and discard the last character of
; the value, which will be the end quote.
; All other tokens have no value, so discard the value before returning.

        cmp     #TOK_NUM
        beq     @encode_number
        cmp     #TOK_STRING
        beq     @encode_string

; If we get here then we have a symbol or a name. Look it up in `keywords` name tables, and if successful,
; output that token instead. Note: Although we have one keyword table, we have separate tokens for symbols and
; names, because if we can't tokenize the keyword, the parser has to be able to distinguish between them.

@encode_symbol_or_name:
        ldax    #keywords
        jsr     find_name
        bcs     @return_terminal_token
        ldx     #11
@find_block:
        cmp     keyword_block_offsets,x ; Find highest-numbered block where offset is >= keyword index
        bcs     @found_block
        dex
        bpl     @find_block
@found_block:
        sbc     keyword_block_offsets,x ; Calculate the offset of the keyword within the block
        sta     B                       ; Offset in B
        txa
        asl     A                       ; Multiply block index by 16 to get base token value
        asl     A
        asl     A
        asl     A
        ora     B
        ldy     decode_name_ptr         ; Reload line_pos+1 since find_name clobbered it
        sta     line_buffer-1,y         ; Overwrite the original token with the keyword token
        sty     line_pos                ; This will become the new line_pos since we replaced the token
@encode_number:
        rts

; When we get here the buffer looks like this:
; T"XYZZY"
; ^ the TOK_STRING token
;  ^ decode_name_ptr
;         ^ line_pos (one last the ending quote, which has EOT set)
; We replace the beginning quote with the string length, excluding the end quote, which remains to
; make LIST easier to implement. The length is (line_pos - 1) - (decode_name_ptr + 1)
; or (line_pos - decode_name_ptr - 2).

@encode_string:
        lda     line_pos
        sbc     decode_name_ptr         ; Carry will be set because we got here via CMP + BEQ
        sbc     #2
        ldy     decode_name_ptr         ; Will point to the quote at the start of the string
        sta     line_buffer,y           ; Replace with length byte

@return_terminal_token:
        lda     C
        rts

