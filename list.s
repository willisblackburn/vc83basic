
; Functions that decode the tokenized program for display on the console.
; Most functions decode from the line pointed to by line_ptr, using line_pos as the read position,
; and decode into buffer, using buffer_pos as the write position.

; LIST statement:
; Scans through the program and prints each line.
; We use line_ptr to list the program.
; It's possible that LIST is being called from within the program, so we save the existing line_ptr value
; on the stack and restore it after so we can resume execution after the LIST statement.

exec_list:
        ldphaa  line_ptr
        jsr     reset_line_ptr
@list_one_line:
        jsr     list_line
        bcs     @done
        ldax    #buffer
        ldy     buffer_pos              ; buffer_pos will be the amount of data written to the buffer
        jsr     write
        jsr     newline
        jsr     advance_line_ptr
        jmp     @list_one_line

@done:
        plstaa  line_ptr
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
        jsr     format_number           ; Format into buffer
        mva     #.sizeof(Line), line_pos    ; Initialize read position to start of data
        jsr     list_statement
        clc
        rts

@done:
        sec
        rts

; Outputs a statement.

list_statement:
        jsr     decode_byte             ; Get statement token
        sta     name_index
        mvax    #statement_name_table, next_name_ptr
@next_name:
        jsr     advance_name_ptr        ; Next name table entry
        bcs     @not_found              ; Found end of name table; should not happen but will just list nothing
        dec     name_index
        bpl     @next_name              ; Keep searching if index is positive (this limits name table to 128 entries)
@not_found:
        jsr     add_whitespace
        ldy     #0
@next_name_byte:
        lda     (name_ptr),y
        php                             ; Remember if EOT bit was set
        and     #$7F                    ; Clear if it was
        jsr     append_buffer
        iny
        plp
        bpl     @next_name_byte
        jsr     rebase_name_ptr         ; Add the name length in Y to name_ptr
@after_directive:
        ldy     #0                      ; Start reading from name_ptr offset 0
@next_byte:
        tya                             ; Read position into A
        clc
        adc     name_ptr                ; Add to name_ptr; A is now low byte of read position
        cmp     next_name_ptr           ; Is it the next name_ptr?
        beq     @done                   ; Finished
        lda     (name_ptr),y
        iny                             ; Move to next byte in name record
        cmp     #' '                    ; Check if it's a directive (not a literal, x00x xxxx)
        bcc     @directive              ; It is
        jsr     append_buffer           ; Write to buffer
        bne     @next_byte              ; Unconditional; Z flag cleared by INC in append_buffer

@directive:
        jsr     rebase_name_ptr         ; Catch up name_ptr
        jsr     decode_byte             ; Decode first byte
        beq     @after_directive        ; Was empty; don't add whitespace
        jsr     add_whitespace
        dec     line_pos                ; Back up so we start with first byte
@next_directive_byte:
        jsr     decode_byte
        beq     @after_directive        ; End of directive
        and     #$7F                    ; To clear EOT
        jsr     append_buffer
        bne     @next_directive_byte    ; Unconditional

@done:
        rts

; Adds whitespace to the output if necessary.
; Whitespace is necessary if buffer_pos > 0 and if buffer[buffer_pos-1] is a name character or is a ')'.
; Y SAFE, BC SAFE, DE SAFE

add_whitespace:
        ldx     buffer_pos              ; Current write position
        beq     @done                   ; Just return if it's zero
        lda     buffer-1,x              ; Get buffer[x-1]
        cmp     #')'
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
