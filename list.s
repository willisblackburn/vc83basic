.include "macros.inc"
.include "basic.inc"

; Functions that decode the tokenized program for display on the console.
; Most functions decode from the line pointed to by line_ptr, using lp as the read position,
; and decode into buffer, using bp as the write position.

; LIST statement:
; Scans through the program and prints each line.
; We use line_ptr to list the program, but it's possible the LIST is being called from wtihin the program,
; so we save the existing line_ptr value on the stack and restore it after.

exec_list:
        ldphaa  line_ptr
        jsr     reset_line_ptr
@list_one_line:
        jsr     list_line
        bcs     @done
        ldax    #buffer
        ldy     bp                      ; bp will be the amount of data written to the buffer
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
        mva     #0, bp                  ; Initialize write position in buffer
        ldy     #Line::number+1         ; Position of line number high byte
        lda     (line_ptr),y            ; Into A
        bmi     @done                   ; If MSB of line number is set, we're at end of program
        tax                             ; Move into X
        dey                             ; Position of line number low byte
        lda     (line_ptr),y
        jsr     format_number           ; Format into buffer
        jsr     putchar_space_buffer
        mva     #Line::data, lp         ; Initialize read position to start of data
        jsr     decode_byte             ; Get statement token
        tay
        ldax    #statement_name_table
        jsr     list_element
        clc
        rts

@done:
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
        pla                             ; Get the last-seen name table entry byte (TODO: use this technique in parser)
        bmi     @done                   ; If the high byte is set then we're done
        ldy     np
        inc     np                      ; Next position
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
        jsr     list_repeated_argument
        jmp     @loop
@done:
        rts                            

; Lists statement or function arguments from the token stream.
; ARGUMENT COUNT MUST BE AT LEAST 1.
; A = the number of arguments to list

.assert TOKEN_NO_VALUE = 0, error

list_multiple_arguments:
        and     #$07                    ; Isolate the count
        sta     argument_count          ; Re-use argument_count from parser module
        jsr     decode_byte             ; Check if the next argument is TOKEN_NO_VALUE
        beq     @no_value               ; If so then don't list
@next_argument:
        dec     lp                      ; Back up to decode the argument
        jsr     list_argument           ; Assume it's an expression for now
@no_value:
        dec     argument_count          ; Done with one argument
        beq     @done                   ; Finish if no more
        jsr     decode_byte             ; Check if next argument is TOKEN_NO_VALUE
        beq     @no_value               
        lda     #','                    ; Output argument separator
        jsr     putchar_buffer
        bne     @next_argument          ; Will never write 0 so this is unconditional branch

@done:
        rts

; Lists repeated arguments.
; Keep reading arguments until we find TOKEN_NO_VALUE, which is conveniently zero.

.assert TOKEN_NO_VALUE = 0, error

list_repeated_argument:
        jsr     decode_byte             ; Get the next byte
        beq     @done                   ; If it's TOKEN_NO_VALUE then done
@next_argument:
        dec     lp                      ; It wasn't, so back up lp
        jsr     list_argument           ; List one argument
        jsr     decode_byte             ; Check the next byte
        beq     @done                   ; If no more arguments then exit
        lda     #','                    ; Otherwise output a comma
        jsr     putchar_buffer
        bne     @next_argument          ; Will never write 0 so this is unconditional branch

@done:
        rts

; Lists an argument value from the token stream.

list_argument_vectors:
        .word   list_no_value
        .word   list_number

list_argument:
        jsr     add_whitespace
        ldphaa  name_ptr                ; Save existing value of name_ptr
        ldpha   np                      ; Save existing name entry read position
        jsr     decode_byte             ; Get the identifier of the next value
        bmi     @variable               ; It's a variable
        tay                             ; Transfer token into Y for vector lookup
        ldax    #list_argument_vectors
        jsr     invoke_indexed_vector   ; Invoke the list function for the token type
        jmp     @done

@variable:
        and     #$7F                    ; Clear high bit leaving variable index
        tay                             ; The variable index into Y
        ldax    variable_name_table_ptr ; Look up name in the variable name table
        jsr     list_element            ; Recursively call list_element to display the name        

@done:
        plsta   np                      ; Recover values previously saved on stack
        plstaa  name_ptr
list_no_value:
        rts

list_number:
        jsr     decode_number           ; It must be a number; decode it (return value in AX)
        jmp     format_number           ; Send it right to format_number
        rts

; Adds whitespace to the output if necessary.
; Whitespace is necessary if bp > 0 and if buffer[bp-1] is a name character.
; Y SAFE

add_whitespace:
        ldx     bp                      ; Current write position
        beq     @done                   ; Just return if it's zero
        lda     buffer-1,x              ; Get buffer[x-1]
        jsr     is_name_character
        bcs     @done
        jsr     putchar_space_buffer
@done:
        rts

