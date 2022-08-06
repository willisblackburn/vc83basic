.include "macros.inc"
.include "basic.inc"

; Functions that decode the tokenized program for display on the console.
; Most functions decode from the line pointed to by line_ptr, using r as the read position,
; and decode into buffer, using w as the write position.

; LIST statement:
; Scans through the program and prints each line.

exec_list:
        jsr     reset_line_ptr
@line_one_line:
        jsr     list_line
        bcs     @end
        ldax    #buffer
        ldy     w
        jsr     write
        jsr     newline
        jsr     advance_line_ptr
        jmp     @line_one_line

@end:
        rts

; Outputs a full line.
; line_ptr = pointer to the line
; Returns with carry flag set if line_pointer points past the end of the program.

list_line:
        mva     #0, w                   ; Initialize write position
        ldy     #Line::number+1         ; Position of line number high byte
        lda     (line_ptr),y            ; Into A
        bmi     @end                    ; If MSB of line number is set, we're at end of program
        tax                             ; Move into X
        dey                             ; Position of line number low byte
        lda     (line_ptr),y
        jsr     format_number           ; Format into buffer
        jsr     putchar_space_buffer
        mva     #Line::data, r          ; Initialize read position to start of data
        jsr     decode_byte             ; Get statement token
        tay
        ldax    #statement_name_table
        jsr     list_element
        clc
        rts

@end:
        sec
        rts

; Outputs a syntax element.
; This function is called recursively, so it pushes the current state of all the variables used by it and the
; functions it calls on the stack. name_ptr and Y keep track of the element being listed.
; AX = pointer to the first entry in the name table
; Y = the index of the syntax element

list_element:
        jsr     get_name_table_entry    ; Sets name_ptr and resets n; should never fail
        ldpha   #0                      ; Pretend that the last-seen name table entry byte was zero
@loop:
        pla                             ; Get the last-seen name table entry byte
        bmi     @done                   ; If the high byte is set then we're done
        ldy     n
        inc     n                       ; Next position
        lda     (name_ptr),y            ; Load the next byte from the name table
        pha                             ; Put on the stack in order to check high bit next time through
        tax                             ; Temporarily store in X
        and     #$60                    ; Check if it's a directive (not a literal, x00x xxxx)
        beq     @directive              ; It is
        txa                             ; Not a directive, must be a single argument
        and     #$7F                    ; Clear high bit if set
        jsr     putchar_buffer
        jmp     @loop                   ; Will never store 0 so this is unconditional branch

@directive:
        txa
        and     #$70                    ; Check if it's a multiple-argument directive (x000 xxxx)
        beq     @multiple               ; Yes
        txa                             ; Get the byte again
        and     #$0C                    ; Check if it's repeated (xxxx 11xx)
        cmp     #$0C
        beq     @repeated               ; Yes
        txa                             ; It's not multiple and not repeated, must be a single argument
        jsr     list_argument           ; Just list one argument value
        jmp     @loop                   ; Will never store 0 so this is unconditional branch

@multiple:
        txa                             ; Get back original directive
        jsr     list_multiple_arguments
        jmp     @loop

@repeated:
        txa                             ; Get back original directive
        jsr     list_repeated_arguments
        jmp     @loop
@done:
        rts                            

; Lists statement or function arguments from the token stream.
; ARGUMENT COUNT MUST BE AT LEAST 1.
; A = the number of arguments to list
; line_ptr = pointer to the current line
; r = read position line (updated) 

list_multiple_arguments:
        and     #$07                    ; Isolate the count
        sta     argument_count          ; Re-use argument_count from parser module
@next_argument:
        jsr     list_argument           ; Assume it's an expression for now
        dec     argument_count          ; Done with one argument
        beq     @done                   ; Finish if no more
        lda     #','                    ; Output argument separator
        jsr     putchar_buffer
        bne     @next_argument          ; Will never write 0 so this is unconditional branch

@done:
        rts

; Lists repeated arguments.
; Keep reading arguments until we find TOKEN_END_REPEAT, which is conveniently zero.

.assert TOKEN_END_REPEAT = 0, error

list_repeated_arguments:
        jsr     decode_byte             ; Get the next byte
        beq     @done                   ; If it's TOKEN_END_REPEAT then done.
@next_argument:
        dec     r                       ; It wasn't, so back up r.
        jsr     list_argument           ; List one argument
        jsr     decode_byte             ; Check the next byte
        beq     @done                   ; If no more arguments then exit
        lda     #','                    ; Otherwise output a comma
        jsr     putchar_buffer
        bne     @next_argument          ; Will never write 0 so this is unconditional branch

@done:
        rts

; Lists an argument value from the token stream.
; line_ptr = pointer to the current line
; r = read position line (updated) 

list_argument:
        jsr     add_whitespace
        ldphaa  name_ptr                ; Save existing value of name_ptr
        ldpha   n                       ; Save existing name entry read position
        jsr     decode_byte             ; Get the identifier of the next value
        bmi     @variable               ; It's a variable
        jsr     decode_number           ; It must be an integer; decode the number (return value in AX)
        jsr     format_number           ; Send it right to format_number
        jmp     @done

@variable:
        and     #$7F                    ; Clear high bit leaving variable index
        tay                             ; The variable index into Y
        ldax    variable_name_table_ptr ; Look up name in the variable name table
        jsr     list_element            ; Recursively call list_element to display the name        

@done:
        plsta   n                       ; Recover values previously saved on stack
        plstaa  name_ptr
        rts

; Adds whitespace to the output if necessary.
; Whitespace is necessary if w > 0 and if buffer[w-1] is a name character.
; Y SAFE

add_whitespace:
        ldx     w                       ; Current write position
        beq     @done                   ; Just return if it's zero
        lda     buffer-1,x              ; Get buffer[x-1]
        jsr     is_name_character
        bcs     @done
        jsr     putchar_space_buffer
@done:
        rts

