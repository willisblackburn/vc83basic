; cc65 runtime
.include "zeropage.inc"

.include "target.inc"
.include "basic.inc"

; Functions that decode the tokenized program for display on the console.
; Most functions decode from the line pointed to by line_ptr, using r as the read position,
; and decode into output_buffer, using w as the write position.

; LIST statement:
; Scans through the program and prints each line.

exec_list:
        jsr     reset_line_ptr
@next_line:
        jsr     update_line_fields
        ldax    line_number             ; Line number into AX
        bmi     @end                    ; If MSB of line number is set, we're at end of program
        ;jsr     print_number
        lda     #' '
        jsr     putchar
        ldy     #3                      ; Start of line data
        lda     (line_ptr),y            ; Get statement token
        iny                             ; Increment Y to 4
        sty     r                       ; and store in the read position register
        tay
        ldax    #statement_name_table
        jsr     list_element
        jsr     newline
        jsr     advance_line_ptr
        jmp     @next_line

@end:
        rts

; Outputs a syntax element.
; This function is called recursively. It sets up name_ptr and Y and saves them on the stack prior to calling
; other functions so that those functions can call back in to this one.
; AX = pointer to the first entry in the name table
; Y = the index of the syntax element

list_element:

        jsr     get_name_table_entry    ; Sets name_ptr; should never fail
        ldy     #0                      ; Start at position 0
@next_byte:
        tya                             ; Save Y on the stack
        pha     
        lda     (name_ptr),y            ; Load the next byte from the name table
        and     #$60                    ; Is it a literal character?
        beq     @handle_arguments       ; Nope
        lda     (name_ptr),y            ; It was a literal character; load the character again
        and     #$7F                    ; Clear high bit if set
        jsr     putchar                 ; Print the character
        jmp     @loop                   ; Continue

@handle_arguments:
        ldphaa  name_ptr                ; Save name_ptr on the stack
        lda     (name_ptr),y            ; Get the byte again
        pha                             ; Save it on the stack since putchar will clobber Y
        lda     #' '                    ; Print a space
        jsr     putchar
        pla                             ; Recover byte
        and     #$0F                    ; Number of arguments
        jsr     list_arguments          ; List them
        plstaa  name_ptr                ; Recover name_ptr
@loop:
        pla                             ; Recover Y
        tay
        lda     (name_ptr),y            ; Load the byte again to check if it has the high bit set
        bmi     @done                   ; High bit is set; end of name table entry
        iny                             ; Next character
        jmp     @next_byte              ; Keep going
@done:
        rts                            

; Lists statement or function arguments from the token stream.
; Unlike parse_arguments, this function does not use the signature table. Instead, we just print arguments using
; the types in the token stream.
; A = the number of arguments to list
; line_ptr = pointer to the current line
; r = read position line (updated) 

list_arguments:

        pha                             ; Argument count at SP+1
@next_argument:
        jsr     list_value              ; Assume it's an expression for now
        tsx                             ; Prepare to access local variables
        lda     $101,x
        dec     $101,x                  ; Decrement argument count
        beq     @done
        lda     #','
        jsr     putchar
        jmp     @next_argument
@done:
        pla                             ; Discard stack frame
        rts

; Lists an expression from the token stream.
; line_ptr = pointer to the current line
; r = read position line (updated) 

list_value:

        ldy     r                       ; Load read position into Y
        inc     r                       ; Skip past this byte
        lda     (line_ptr),y            ; Read a byte from the stream
        bmi     @variable               ; It's a variable
        jsr     decode_number           ; It must be an integer; decode the number (return value in AX)
        ;jsr     print_number            ; Send it right to print_number
        rts

@variable:
        and     #$7F                    ; Clear high bit leaving variable index
        tay                             ; The variable index into Y
        ldax    variable_name_table_ptr ; Look up name in the variable name table
        jsr     list_element            ; Recursively call list_element to display the name        
        rts

