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
@next_line:
        mvaa    next_line_ptr, line_ptr
        mvy     #0, buffer_pos          ; Initialize write position in buffer (also set Y to next_line_offset)
        lda     (line_ptr),y            ; Next line offset into A
        beq     @done                   ; If it's the null statement then we're at the end of the program
        jsr     line_number_to_string
        mva     #.sizeof(Line), line_pos
        jsr     list_statements
        ldax    #buffer
        ldy     buffer_pos              ; buffer_pos will be the amount of data written to the buffer
        jsr     write
        jsr     newline
        jsr     advance_next_line_ptr
        jmp     @next_line

@done:
        plsta   next_line_pos
        plstaa  next_line_ptr
        jmp     next_statement

; Outputs all of the statements on a line.

.assert MISC_STATEMENT = 0, error
.assert MISC_THEN = 1, error
.assert MISC_GOTO = 2, error

list_statements:
        jsr     decode_byte             ; Get statement token
        tay                             ; Set up for list_tokenized_name
        ldax    #statement_name_table
@token:
        jsr     expand_tokenized_name
        ldy     line_pos                ; Exit w/o adding whitespace if there's no more data on the line
        lda     (line_ptr),y
        beq     @done
        jsr     add_whitespace
@next:
        jsr     decode_byte             ; Get the next byte; Y is line_pos
        beq     @done
        and     #$7F                    ; Clear EOT
        sec                             ; Prepare to look for tokens
        sbc     #$04                    ; Unary operator
        cmp     #4
        bcs     @try_misc
        tay
        ldax    #unary_operator_name_table
        bcc     @token
@try_misc:
        sbc     #$08 - $04              ; Clause
        cmp     #8
        bcs     @try_operator
        tay
        pha                             ; Remember the value to check for STATEMENT and THEN later
        ldax    #extra_name_table
        jsr     expand_tokenized_name   ; Call directly in order to handle STATEMENT and THEN
        jsr     add_whitespace          ; Can just add because there's always something after a misc token
        pla
        cmp     #MISC_GOTO              ; Less than GOTO means STATEMENT or THEN
        bcc     list_statements         ; If so then start listing statements all over again
        bcs     @next                   ; Unconditional
@try_operator:
        sbc     #$10 - $08              ; Binary operator
        cmp     #16
        bcs     @try_function
        tay
        ldax    #operator_name_table
        bcc     @token                  ; Unconditional
@try_function:
        sbc     #$60 - $10              ; Function
        cmp     #32
        bcs     @default
        tay
        ldax    #function_name_table
        jsr     expand_tokenized_name   ; Call directly becuase we don't want to add whitespace after
        jmp     @next
@default:
        sbc     #$A0                    ; Subtract to cycle the value A back around to its original value
        jsr     append_buffer
        bne     @next                   ; Unconditional because append_buffer does INC

@done:
        rts

; Given a name table index obtained from a token, list the name from the name table.
; AX = pointer to the start of the name table
; Y = index number

expand_tokenized_name:
        jsr     get_name                ; Get the statement name
        bcs     @done                   ; Shouldn't happen, but just in case
        ldy     #0
        lda     (name_ptr),y
        and     #$7F                    ; In case EOT is set
        cmp     #'A'                    ; Only add whitespace before tokenized name if it starts with a letter
        bcc     @next_name_byte
        jsr     add_whitespace
@next_name_byte:
        lda     (name_ptr),y
        php                             ; Remember if EOT bit was set
        and     #$7F                    ; Clear if it was
        jsr     append_buffer
        iny
        plp
        bpl     @next_name_byte
@done:
        rts

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
