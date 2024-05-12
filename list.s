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

list_line:
        mva     #0, buffer_pos          ; Initialize write position in buffer
        ldy     #Line::number+1         ; Position of line number high byte
        lda     (line_ptr),y            ; Into A
        bmi     @done                   ; If MSB of line number is set, we're at end of program
        tax                             ; Move into X
        dey                             ; Position of line number low byte
        lda     (line_ptr),y
        jsr     format_number           ; Format into buffer
        jsr     append_buffer_space
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
        jsr     get_name_table_entry    ; Sets name_ptr and resets name_pos; should never fail
@next_name:
        jsr     append_from_name_table_entry    ; Outputs (possibly zero) characters from the name table
        bcs     @done                   ; If there is nothing after then exit
        tya                             ; Otherwise there is a directive in Y
        jsr     list_directive
        inc     name_pos                ; Next byte
        bne     @next_name              ; name_pos is always >0 so unconditional

@done:
        rts

; Outputs a name from a name table.
; AX = pointer to the first entry in the name table
; Y = the index of the entry

list_name:
        jsr     get_name_table_entry
        jsr     append_from_name_table_entry
        clc                             ; Signal success
        rts

; Outputs characters from the name table entry starting at name_pos, until reaching the last character or a
; directive.
; name_ptr = pointer to the table entry
; name_pos = the name table entry position
; Returns carry set if the last character of the name was also the last byte of the name table entry, or carry clear
; if the next character is a directive, which will be in Y.

append_from_name_table_entry:
        jsr     read_name_table_byte    ; Get the first byte
        bcs     @done                   ; No first byte
        jsr     is_name_character       ; Is it a name character?
        bcs     @next_character         ; It's not; don't add whitespace
        jsr     add_whitespace
@next_character:
        jsr     read_name_table_byte    ; Get the next byte
        bcs     @done                   ; If last byte then return
        tay                             ; Store temporarily in Y
        and     #$60                    ; Check if it's a directive (not a literal, x00x xxxx)
        beq     @done                   ; It is, return with carry still clear
        tya                             ; Get character back from Y
        jsr     append_buffer
        inc     name_pos                ; Next character
        bne     @next_character         ; name_pos is always >0 so unconditional

@done:
        rts

list_argument_type_vectors:
        .word   list_variable-1             ; NT_VAR
        .word   list_repeated_variable-1    ; NT_RPT_VAR

; Lists a single directive from the token stream.
; A = the directive

; Make sure NT_VAR is the first typed directive
.assert NT_VAR = $10, error

list_directive:
        tay                             ; Keep in Y while using A to save state
        ldphaa  name_ptr                ; Save existing value of name_ptr
        ldpha   name_pos                ; Save existing name entry read position
        tya                             ; Recover directive from Y
        sec
        sbc     #NT_VAR                 ; If we can subtract NT_VAR without borrowing then it's a single-arg directive
        bcs     @single
        tya
        jsr     list_argument_list
        jmp     @pop

@single:
        tay                             ; The value left in A after subtracting NT_VAR is the vector index
        ldax    #list_argument_type_vectors
        jsr     invoke_indexed_vector   ; Jump to the parser for the argument type
@pop:
        plsta   name_pos                ; Recover values previously saved on stack
        plstaa  name_ptr
        rts

list_argument_list:
        and     #$07                    ; Isolate the count
        sta     argument_count          ; Re-use argument_count from parser module
        jsr     decode_byte             ; Check if the next argument is TOKEN_NO_VALUE
        beq     @no_value               ; If so then don't list
@next_argument:
        dec     line_pos                ; Back up
        jsr     list_expression         ; List the expression
@no_value:
        dec     argument_count          ; Done with one argument
        beq     @done                   ; Finish if no more
        jsr     decode_byte             ; Check if next argument is TOKEN_NO_VALUE
        beq     @no_value               
        lda     #','                    ; Output argument separator
        jsr     append_buffer
        bne     @next_argument          ; Will never write 0 so this is unconditional branch

@done:
        rts

list_vectors:
        .word   list_variable-1         ; XH_VAR
        .word   list_number-1           ; XH_NUM
        .word   list_operator-1         ; XH_OP
        .word   list_unary_operator-1   ; XH_UNARY_OP
        .word   list_paren-1            ; XH_PAREN

list_expression:
        ldax    #list_vectors
        jmp     decode_expression

list_variable:
        jsr     decode_variable
        tay         
        ldax    variable_name_table_ptr ; Look up name in the variable name table
        jmp     list_name

loop_list_repeated_variable:
        lda     #','                    ; Write ',' to output
        jsr     append_buffer
list_repeated_variable:
        jsr     list_variable           ; List one variable
        ldy     line_pos                ; Peek next byte
        lda     (line_ptr),y
        bne     loop_list_repeated_variable ; Not TOKEN_NO_VALUE so keep going
        inc     line_pos                ; Skip over TOKEN_NO_VALUE
        clc                             ; Signal success
        rts

list_number:
        jsr     add_whitespace
        jsr     decode_number           ; Decode the number
        jsr     format_number           ; Send it right to format_number
        clc                             ; Signal success
        rts

list_operator:
        jsr     decode_operator
        tay         
        ldax    #operator_name_table
        jmp     list_name

list_unary_operator:
        jsr     add_whitespace
        jsr     decode_unary_operator
        tay         
        ldax    #unary_operator_name_table
        jmp     list_name

list_paren:
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
        cmp     #')'                    ; Is it ')'?
        beq     append_buffer_space     ; Yes, add a space
        jsr     is_name_character       ; Is it a name character?
        bcc     append_buffer_space     ; Yes
@done:
        rts

; Writes a single byte to buffer at position buffer_pos and increments buffer_pos.
; Does not check for buffer overflow; we assume this can't happen.
; STA is the last operation so zero flag will be set if we wrote zero.
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
