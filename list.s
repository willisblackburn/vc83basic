.include "macros.inc"
.include "basic.inc"

; Functions that decode the tokenized program for display on the console.
; Most functions decode from the line pointed to by line_ptr, using line_pos as the read position,
; and decode into buffer, using buffer_pos as the write position.

; LIST statement:
; Scans through the program and prints each line.
; We use line_ptr and next_line_ptr to list the program.
; It's possible that LIST is being called from within the program, so we save the existing next_line_ptr value
; on the stack and restore it after so we can resume execution after the LIST statement.

exec_list:
        ldphaa  next_line_ptr
        ldpha   next_line_pos
        jsr     reset_next_line_ptr
@list_one_line:
        mvaa    next_line_ptr, line_ptr
        jsr     list_line
        bcs     @done
        ldax    #buffer
        ldy     buffer_pos              ; buffer_pos will be the amount of data written to the buffer
        jsr     write
        jsr     newline
        jsr     advance_next_line_ptr
        jmp     @list_one_line

@done:
        plsta   next_line_pos
        plstaa  next_line_ptr
        clc                             ; LIST always succeeds
        rts

; Outputs a full line.
; line_ptr = pointer to the line
; Returns with carry flag set if line_ptr points to the end of the program.

.assert Line::next_line_offset = 0, error
.assert Line::number = 1, error

list_line:
        mvy     #0, buffer_pos          ; Initialize write position in buffer (also set Y to next_line_offset)
        lda     (line_ptr),y            ; Next line offset into A
        beq     @done                   ; If it's the null statement then we're at the end of the program
        ldy     #Line::number+1         ; Load line number high byte
        lda     (line_ptr),y
        tax                             ; Move into X
        dey                             ; Position of line number low byte
        lda     (line_ptr),y
        jsr     int_to_fp
        jsr     fp_to_string            ; Format into buffer
        mva     #.sizeof(Line), next_line_pos   ; Initialize read position to start of data
        bne     @first_statement        ; Unconditionally skip over code to write separator

@next_statement:
        lda     #':'
        jsr     append_buffer
@first_statement:
        mva     next_line_pos, line_pos ; Move to start of next statement
        jsr     decode_byte             ; Read next statement offset
        sta     next_line_pos           ; Store in next_line_pos
        jsr     list_statement
        lda     next_line_pos
        ldy     #Line::next_line_offset ; Load the next line offset
        cmp     (line_ptr),y            ; Is the next statement offset also the next line offset?
        bne     @next_statement         ; If not then write another statement
        clc
        rts

@done:
        sec
        rts

; Outputs a statement.

list_statement:
        jsr     decode_byte             ; Get statement token
        tay                             ; Set up for list_tokenized_name
        ldax    #statement_name_table
        jsr     list_tokenized_name
@after_directive:
        ldy     #0                      ; Start reading from name_ptr offset 0
@next_byte:
        tya                             ; Read position into A
        clc
        adc     name_ptr                ; Add to name_ptr; A is now low byte of read position
        cmp     next_name_ptr           ; Is it the next name_ptr?
        beq     @done                   ; Finished
        tya                             ; Test Y
        bne     @not_initial_alpha      ; Not first character in group
        lda     (name_ptr),y
        cmp     #'A'                    ; Check if it's alpha
        bcc     @not_initial_alpha      ; No
        jsr     add_whitespace
@not_initial_alpha:
        lda     (name_ptr),y
        iny                             ; Move to next byte in name table data
        cmp     #' '                    ; Check if it's a directive (not a literal, x00x xxxx)
        bcc     @directive              ; It is
        jsr     append_buffer           ; Write to buffer
        bne     @next_byte              ; Unconditional; Z flag cleared by INC in append_buffer

@done:
        rts

@directive:
        sta     B                       ; Save the directive in B
        jsr     rebase_name_ptr         ; Catch up name_ptr
        phzp    NAME_STATE, NAME_STATE_SIZE
        lda     B                       ; Check the directive
        cmp     #NT_STATEMENT           ; Statements require special handling
        bne     @add_whitespace_if_not_end
        jsr     list_statement          ; Recursively list statement
        jmp     @directive_end

@add_whitespace_if_not_end:
        jsr     decode_byte             ; Decode first byte
        beq     @directive_end          ; Was empty; don't add whitespace
        jsr     add_whitespace
        dec     line_pos                ; Back up so we start with first byte
@next_directive_byte:
        jsr     decode_byte
        beq     @directive_end          ; End of directive
        tax                             ; Save in X
        sec
        sbc     #TOKEN_UNARY_OP
        cmp     #8                      ; Number of possible unary operators
        bcs     @not_unary_operator
        tay
        ldax    #unary_operator_name_table
        jsr     list_tokenized_name
        bcc     @add_whitespace_if_not_end      ; Unconditional because list_tokenized_name always clears carry

@not_unary_operator:
        sbc     #(TOKEN_OP - TOKEN_UNARY_OP)
        cmp     #16                     ; Number of possible binary operators
        bcs     @not_operator
        tay
        ldax    #operator_name_table
        jsr     list_tokenized_name
        bcc     @add_whitespace_if_not_end       ; Unconditional because list_tokenized_name always clears carry

@not_operator:
        sbc     #(TOKEN_FUNCTION - TOKEN_OP)
        cmp     #32
        bcs     @not_function
        tay
        ldax    #function_name_table
        jsr     list_tokenized_name
        lda     #'('                    ; Function token implies following '('
        bne     @append                 ; Unconditional     

@not_function:
        txa                             ; Restore original byte
        and     #$7F                    ; To clear EOT
@append:
        jsr     append_buffer
        bne     @next_directive_byte    ; Unconditional

@directive_end:
        plzp    NAME_STATE, NAME_STATE_SIZE
        jmp     @after_directive

; Given a name table index obtained from a token, list the name from the name table.
; AX = pointer to the start of the name table
; Y = index number

list_tokenized_name:
        stax    next_name_ptr           ; This will be copied into name_ptr
        sty     name_index              ; Track the index in name_index
@next_name:
        jsr     advance_name_ptr        ; Next name table entry
        bcs     @not_found              ; Found end of name table; should not happen but will just list nothing
        dec     name_index
        bpl     @next_name              ; Keep searching if index is positive (this limits name table to 128 entries)
@not_found:
        ldy     #0
        lda     (name_ptr),y
        and     #$7F                    ; In case EOT is set
        cmp     #'A'                    ; Only add whitespace before tokenized name if it starts with a letter
        bcc     @next_byte
        jsr     add_whitespace
@next_byte:
        lda     (name_ptr),y
        php                             ; Remember if EOT bit was set
        and     #$7F                    ; Clear if it was
        jsr     append_buffer
        iny
        plp
        bpl     @next_byte
        jmp     rebase_name_ptr         ; Add the name length in Y to name_ptr

; Adds whitespace to the output if necessary.
; Whitespace is necessary if buffer_pos > 0 and if buffer[buffer_pos-1] is a name character or is a ')' or '"'.
; Y SAFE, BC SAFE, DE SAFE

add_whitespace:
        ldx     buffer_pos              ; Current write position
        beq     @done                   ; Just return if it's zero
        lda     buffer-1,x              ; Get buffer[x-1]
        cmp     #')'
        beq     append_buffer_space
        cmp     #'"'
        beq     append_buffer_space
        cmp     #'_'
        beq     append_buffer_space
        sec
        sbc     #'0'
        cmp     #10
        bcc     append_buffer_space
        sbc     #'A' - '0'
        cmp     #26
        bcc     append_buffer_space
@done:
        rts

; Writes a single byte to buffer at position buffer_pos and increments buffer_pos.
; Does not check for buffer overflow; we assume this can't happen.
; INC will leave zero flag set as long as buffer_pos hasn't overrun.
; A = the byte to write (preserved)
; buffer_pos = the buffer position (updated)
; Y SAFE, BC SAFE, DE SAFE

append_buffer_space:
        lda     #' '
append_buffer:
        ldx     buffer_pos              ; Load position
        inc     buffer_pos              ; Incrment position
        sta     buffer,x                ; Store A in buffer
        rts
