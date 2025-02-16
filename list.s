.include "macros.inc"
.include "basic.inc"

; Functions that decode the tokenized program for display on the console.
; Most functions decode from the line pointed to by line_ptr, using line_pos as the read position,
; and decode into buffer, using buffer_pos as the write position.

; LIST statement:
; Scans through the program and prints each line.
; We use line_ptr and next_line_ptr to list the program.
; It's possible the LIST is being called from within the program, so we save the existing next_line_ptr value
; on the stack and restore it after so we can resume execution after the LIST statement.

exec_list:
        ldphaa  next_line_ptr
        jsr     reset_next_line_ptr
@list_one_line:
        mvaa    next_line_ptr, line_ptr
        jsr     advance_next_line_ptr
        jsr     list_line
        bcs     @done
        ldax    #buffer
        ldy     buffer_pos              ; buffer_pos will be the amount of data written to the buffer
        jsr     write
        jsr     newline
        jmp     @list_one_line

@done:
        plstaa  next_line_ptr
        clc                             ; LIST always succeeds
        rts

; Outputs a full line.
; line_ptr = pointer to the line
; Returns with carry flag set if line_ptr points to the end of the program.

list_line:
        mva     #0, buffer_pos          ; Initialize write position in buffer
        ldy     #Line::number+1         ; Position of line number high byte
        lda     (line_ptr),y            ; Into A
        bmi     @done                   ; If MSB of line number is set, we're at end of program
        tax                             ; Move into X
        dey                             ; Position of line number low byte
        lda     (line_ptr),y
        jsr     format_number           ; Format into buffer
        mva     #Line::data, line_pos   ; Initialize read position to start of data
        jsr     list_statement
        clc
        rts

@done:
        sec
        rts

; Outputs a statement.

list_statement:
        jsr     decode_byte             ; Get statement token
        tay
        ldax    #statement_name_table
        jsr     list_tokenized_name
        jsr     rebase_name_ptr         ; Add the name length in Y to name_ptr
@after_directive:
        ldy     #0                      ; Start reading from name_ptr offset 0
@next:
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
        bne     @next                   ; Unconditional; Z flag cleared by INC in append_buffer

@directive:
        tax                             ; Save directive in X
        jsr     rebase_name_ptr         ; Catch up name_ptr
        txa                             ; Get directive
        jsr     list_directive
        jmp     @after_directive

@done:
        rts

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
        ldax    name_ptr                ; Output from name_ptr
        ldy     #0                      ; Start at offset 0

; Fall through

; Output text from the line up to EOT.
; AX = the source pointer
; Y = the offset from the source pointer
; Returns the new offset in Y.

list_characters_to_eot:
        stax    src_ptr
        lda     (src_ptr),y             ; Check first character to see if we need to add whitespace
        and     #$7F                    ; Clear high bit if it's set
        cmp     #'A'
        bcc     @next
        jsr     add_whitespace
@next:
        lda     (src_ptr),y
        bmi     @last
        jsr     append_buffer
        iny
        bne     @next
@last:
        iny                             ; Increment position past the last character
        and     #$7F                    ; Clear high bit
        clc                             ; Signal success for the benefit of callers who JMP here
        jmp     append_buffer

list_argument_type_vectors:
        .word   list_literal-1              ; NT_VAR
        .word   list_repeated_literal-1     ; NT_RPT_VAR
        .word   list_literal-1              ; NT_NUMBER
        .word   list_repeated_literal-1     ; NT_RPT_NUMBER

; Lists a single directive from the token stream.
; A = the directive

; Make sure NT_VAR is the first single-arg directive
.assert NT_VAR = $10, error

list_directive:
        tay                             ; Keep in Y while using A to save state
        phzp    name_ptr, 4
        tya                             ; Recover directive from Y
        sec
        sbc     #NT_VAR                 ; If we can subtract NT_VAR without borrowing then it's a single-arg directive
        bcs     @single
        tya
        jsr     list_argument_list
        jmp     @pop_state

@single:
        tay                             ; The value left in A after subtracting NT_VAR is the vector index
        ldax    #list_argument_type_vectors
        jsr     invoke_indexed_vector   ; Jump to the parser for the argument type
@pop_state:
        plzp    name_ptr, 4
        rts

list_argument_list:
        and     #$07                    ; Isolate the count
        pha                             ; Save on the stack
        jsr     decode_byte             ; Check if the next argument is 0
        beq     @no_value               ; If so then don't list
@next_argument:
        dec     line_pos                ; Back up
        jsr     list_expression         ; List the expression
@no_value:
        tsx                             ; Set up stack access
        dec     $101,x                  ; Done with one argument
        beq     @done                   ; Finish if no more
        jsr     decode_byte             ; Check if next argument is 0
        beq     @no_value               
        lda     #','                    ; Output argument separator
        jsr     append_buffer
        bne     @next_argument          ; Will never write 0 so this is unconditional branch

@done:
        pla                             ; Pop and discard the argument counter
        rts

list_vectors:
        .word   list_unary_operator-1   ; XH_UNARY_OP
        .word   list_operator-1         ; XH_OP
        .word   list_literal-1          ; XH_NUMBER
        .word   list_literal-1          ; XH_VAR
        .word   list_paren-1            ; XH_PAREN

list_expression:
        ldax    #list_vectors
        jmp     decode_expression

list_unary_operator:
        jsr     add_whitespace
        jsr     decode_unary_operator
        tay         
        ldax    #unary_operator_name_table
        jmp     list_tokenized_name

list_operator:
        jsr     decode_operator
        tay         
        ldax    #operator_name_table
        jmp     list_tokenized_name

list_literal:
        jsr     add_whitespace
        ldax    line_ptr
        ldy     line_pos
        jsr     list_characters_to_eot
        sty     line_pos                ; Update line_pos
        rts

loop_list_repeated_literal:
        lda     #','                    ; Write ',' to output
        jsr     append_buffer
list_repeated_literal:
        jsr     list_literal            ; List one number
        ldy     line_pos                ; Peek next byte
        lda     (line_ptr),y
        bne     loop_list_repeated_literal  ; Not 0 so keep going
        inc     line_pos                ; Skip over 0
        clc                             ; Signal success
        rts

list_paren:
        inc     line_pos                ; Skip over '('
        jsr     add_whitespace
        lda     #'('
        jsr     append_buffer
        ldax    #list_vectors
        jsr     decode_expression
        lda     #')'
        jsr     append_buffer
        clc                             ; Signal success
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
