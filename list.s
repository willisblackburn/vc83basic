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
        stax    DE                      ; Park the new name_ptr
        ldphaa  name_ptr                ; Save existing value of name_ptr
        ldpha   n                       ; Save existing name entry read position
        ldax    DE                      ; Retrieve new name_ptr value
        jsr     get_name_table_entry    ; Sets name_ptr and resets n; should never fail
@next_byte:
        ldy     n
        inc     n                       ; Next position
        lda     (name_ptr),y            ; Load the next byte from the name table
        pha                             ; Push so I can recover later to check high bit
        and     #$60                    ; Is it a literal character?
        beq     @handle_arguments       ; Nope
        lda     (name_ptr),y            ; It was a literal character; load the character again
        and     #$7F                    ; Clear high bit if set
        jsr     putchar_buffer
        bne     @loop                   ; Will never store 0 so this is unconditional branch

@handle_arguments:
        jsr     add_whitespace
        lda     (name_ptr),y            ; Get the byte again
        and     #$0F                    ; Number of arguments
        jsr     list_arguments          ; List them
@loop:
        pla                             ; Recover last name entry byte from stack
        bpl     @next_byte              ; Keep going
        plsta   n                       ; Recover values previously saved on stack
        plstaa  name_ptr
        rts                            

; Lists statement or function arguments from the token stream.
; Unlike parse_arguments, this function does not use the signature table. Instead, we just print arguments using
; the types in the token stream.
; ARGUMENT COUNT MUST BE AT LEAST 1 (although that argument can be optional).
; A = the number of arguments to list
; line_ptr = pointer to the current line
; r = read position line (updated) 

list_arguments:
        and     #NT_MASK_ARGUMENT_COUNT ; Isolate the count
        sta     argument_count          ; Re-use argument_count from parser module
@next_argument:
        jsr     list_value              ; Assume it's an expression for now
        dec     argument_count          ; Done with one argument
        beq     @done                   ; Finish if no more
        lda     #','                    ; Output argument separator
        jsr     putchar_buffer
        jmp     @next_argument
@done:
        rts

; Lists an expression from the token stream.
; line_ptr = pointer to the current line
; r = read position line (updated) 

list_value:
        jsr     decode_byte             ; Get statement number
        bmi     @variable               ; It's a variable
        jsr     decode_number           ; It must be an integer; decode the number (return value in AX)
        jsr     format_number           ; Send it right to format_number
        rts

@variable:
        and     #$7F                    ; Clear high bit leaving variable index
        tay                             ; The variable index into Y
        ldax    variable_name_table_ptr ; Look up name in the variable name table
        jsr     list_element            ; Recursively call list_element to display the name        
        rts

; Adds whitespae to the output if necessary.
; Whitespace is necessary if w > 0 and if buffer[w-1] is a name character.

add_whitespace:
        ldx     w                       ; Current write position
        beq     @done                   ; Just return if it's zero
        lda     buffer-1,x              ; Get buffer[x-1]
        jsr     is_name_character
        bcs     @done
        jsr     putchar_space_buffer
@done:
        rts

