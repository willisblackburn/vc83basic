; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

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
        lda     #$FF
        sta     line_number             ; Set line number to max in case user did not provide arguments
        sta     line_number+1
        ldy     line_pos                ; Look to see if there are arguments
        lda     (line_ptr),y
        beq     @next_line              ; Nothing after LIST, just go
        jsr     get_line_number         ; Go get it
        jsr     find_line               ; Stores the line number in line_number
        ldy     line_pos                ; Anything else?
        lda     (line_ptr),y
        beq     @next_line              ; Nope: the value in line_number becomes the terminating line number
        inc     line_pos                ; There's another arg, so skip over the ','
        jsr     get_line_number         ; Save the ending line number in line_number
        stax    line_number
@next_line:
        mvaa    next_line_ptr, line_ptr
        jsr     list_line
        ldax    #buffer
        ldy     buffer_pos              ; buffer_pos will be the amount of data written to the buffer
        beq     @done                   ; If it was zero bytes then no more lines
        jsr     write
        jsr     newline
        jsr     advance_next_line_ptr
        ldy     #Line::number+1         ; Check for the ending line number
        lda     (line_ptr),y
        cmp     line_number+1
        bcc     @next_line              ; High byte is less
        dey                             ; Check low byte
        lda     (line_ptr),y
        cmp     line_number
        bcc     @next_line              ; Less

@done:
        plsta   next_line_pos
        plstaa  next_line_ptr
        rts

; Outputs a line with a line number and all statements separated by ':'.
; line_ptr = the line to write

list_line:
        mvy     #0, buffer_pos          ; Initialize write position in buffer (also set Y to next_line_offset)
        sty     string_flag             ; Make sure we're not in string mode
        lda     (line_ptr),y            ; Next line offset into A
        beq     @done                   ; If it's the null statement then we're at the end of the program
        jsr     line_number_to_string
        mva     #.sizeof(Line), line_pos
@next:
        jsr     list_statement
        ldy     #0
        lda     line_pos                ; Current position
        cmp     (line_ptr),y            ; At next line offset?
        bcs     @done                   ; Yep
        lda     #':'                    ; Else write ':' and next statement
        jsr     append_buffer
        jmp     @next

@done:
        rts

; Outputs a statement.

.assert CLAUSE_THEN = 0, error

list_statement:
        inc     line_pos                ; Skip past the next statement offset; we don't use it
@then:
        jsr     decode_byte             ; Get statement token
        bmi     @extension              ; It's an extension
        tay                             ; Set up for list_tokenized_name
        ldax    #statement_name_table
        bne     @token                  ; Unconditional
@extension:
        and     #$7F
        tay
        ldax    #ex_statement_name_table
@token:
        jsr     expand_tokenized_name
        ldy     line_pos                ; Exit w/o adding whitespace if there's no more data on the line
        lda     (line_ptr),y
        bne     @not_empty
        inc     line_pos
        rts
@not_empty:
        jsr     add_whitespace
@next:
        jsr     decode_byte             ; Get the next byte; Y is line_pos
        beq     @done
        and     #$7F                    ; Clear EOT
        cmp     #'"'                    ; If it's double quote then just output
        bne     @check_string_flag
        lda     string_flag
        eor     #$80                    ; Toggle bit 7
        sta     string_flag
        lda     #'"'                    ; Reload the quote
@check_string_flag:
        ldx     string_flag
        bmi     @output
        sec                             ; Prepare to look for tokens
        sbc     #$04                    ; Unary operator
        cmp     #4
        bcs     @try_clause
        tay
        ldax    #unary_operator_name_table
        bcc     @token
@try_clause:
        sbc     #$08 - $04              ; Clause
        cmp     #8
        bcs     @try_operator
        tay
        pha                             ; Remember the value to check for THEN later
        ldax    #clause_name_table
        jsr     expand_tokenized_name
        jsr     add_whitespace          ; Can just add because there's always something after a clause token
        pla
        beq     @then                   ; If it was 0 (THEN), restart statement
        bne     @next                   ; Unconditional
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
@output:
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
        beq     @done                   ; If first character is just EOT the output nothing
        cmp     #'A'                    ; Only add whitespace before tokenized name if it starts with a letter
        bcc     @next_name_byte
        cmp     #'^'                    ; ^ is always a pain because it's not grouped with other symbols
        beq     @next_name_byte
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
