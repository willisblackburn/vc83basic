.include "macros.inc"
.include "basic.inc"

; Functions that decode the tokenized program for display on the console.
; Most functions decode from the line pointed to by line_ptr, using lp as the read position,
; and decode into buffer, using bp as the write position.

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
        ldy     bp                      ; bp will be the amount of data written to the buffer
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
        mva     #0, bp                  ; Initialize write position in buffer
        ldy     #Line::number+1         ; Position of line number high byte
        lda     (line_ptr),y            ; Into A
        bmi     @done                   ; If MSB of line number is set, we're at end of program
        tax                             ; Move into X
        dey                             ; Position of line number low byte
        lda     (line_ptr),y
        jsr     format_number           ; Format into buffer
        jsr     append_buffer_space
        mva     #Line::data, lp         ; Initialize read position to start of data
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
        jsr     get_name_table_entry    ; Sets name_ptr and resets np; should never fail
@next_name:
        jsr     append_from_name_table_entry    ; Outputs (possibly zero) characters from the name table
        bcs     @done                   ; If there is nothing after then exit
        tya                             ; Otherwise there is a directive in Y
        jsr     list_directive
        inc     np                      ; Next byte
        jmp     @next_name

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

; Outputs characters from the name table entry starting at np, until reaching the last character or a
; directive.
; name_ptr = pointer to the table entry
; np = the name table entry position
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
        inc     np                      ; Next character
        jmp     @next_character

@done:
        rts

list_argument_type_vectors:
        .word   list_variable-1             ; NT_VAR
        .word   list_repeated_variable-1    ; NT_RPT_VAR
        .word   list_number-1               ; NT_NUM
        .word   list_repeated_number-1      ; NT_RPT_NUM

; Lists a single directive from the token stream.
; A = the directive

; Make sure NT_VAR is the first typed directive
.assert NT_VAR = $10, error

list_directive:
        tay                             ; Keep in Y while using A to save state
        ldphaa  name_ptr                ; Save existing value of name_ptr
        ldpha   np                      ; Save existing name entry read position
        tya                             ; Recover directive from Y
        sec
        sbc     #NT_VAR                 ; If we can subtract NT_VAR without borrowing then it's a single-arg directive
        bcs     @single
        and     #$0F                    ; Mask out top 4 bits
        jsr     list_argument_list
        jmp     @pop

@single:
        tay                             ; The value left in A after subtracting NT_VAR is the vector index
        ldax    #list_argument_type_vectors
        jsr     invoke_indexed_vector   ; Jump to the parser for the argument type
@pop:
        plsta   np                      ; Recover values previously saved on stack
        plstaa  name_ptr
        rts

list_argument_list:
        and     #$07                    ; Isolate the count
        sta     argument_count          ; Re-use argument_count from parser module
        jsr     decode_byte             ; Check if the next argument is TOKEN_NO_VALUE
        beq     @no_value               ; If so then don't list
@next_argument:
        dec     lp                      ; Back up
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

; Following logic depends on TOKEN_NO_VALUE being 0
.assert TOKEN_NO_VALUE = 0, error

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
        ldy     lp                      ; Peek next byte
        lda     (line_ptr),y
        bne     loop_list_repeated_variable ; Not TOKEN_NO_VALUE so keep going
        inc     lp                      ; Skip over TOKEN_NO_VALUE
        clc                             ; Signal success
        rts

list_number:
        jsr     add_whitespace
        jsr     decode_number           ; Decode the number
        jsr     format_number           ; Send it right to format_number
        clc                             ; Signal success
        rts

loop_list_repeated_number:
        lda     #','                    ; Write ',' to output
        jsr     append_buffer
list_repeated_number:
        jsr     list_number             ; List one number
        ldy     lp                      ; Peek next byte
        lda     (line_ptr),y
        bne     loop_list_repeated_number   ; Not TOKEN_NO_VALUE so keep going
        inc     lp                      ; Skip over TOKEN_NO_VALUE
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
; Whitespace is necessary if bp > 0 and if buffer[bp-1] is a name character or is a ')'.
; Y SAFE, BC SAFE, DE SAFE

add_whitespace:
        ldx     bp                      ; Current write position
        beq     @done                   ; Just return if it's zero
        lda     buffer-1,x              ; Get buffer[x-1]
        cmp     #')'                    ; Is it ')'?
        beq     append_buffer_space     ; Yes, add a space
        jsr     is_name_character       ; Is it a name character?
        bcc     append_buffer_space     ; Yes
@done:
        rts

; Writes a single byte to buffer at position bp and increments bp.
; Does not check for buffer overflow; we assume this can't happen.
; STA is the last operation so zero flag will be set if we wrote zero.
; A = the byte to write (preserved)
; bp = the buffer position (updated)
; Y SAFE, BC SAFE, DE SAFE

append_buffer_space:
        lda     #' '
append_buffer:
        ldx     bp                      ; Load position
        inc     bp                      ; Incrment position
        sta     buffer,x                ; Store A in buffer
        rts
