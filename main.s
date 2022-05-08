; cc65 runtime
.include "zeropage.inc"

.include "target.inc"
.include "basic.inc"

ready_message: .byte "READY"
ready_length = * - ready_message

error_message: .byte "ERROR"
error_length = * - error_message

statement_name_table:
        .byte   'L', 'I', 'S', 'T' | NT_END
        .byte   'R', 'U', 'N', NT_1ARG | NT_END
        .byte   'P', 'R', 'I', 'N', 'T', NT_1ARG | NT_END
        .byte   'L', 'E', 'T', NT_1ARG, '=', NT_1ARG | NT_END
        .byte   0

statement_signature_table:
        .byte   TYPE_NONE, TYPE_NONE
        .byte   TYPE_NONE, TYPE_NONE
        .byte   TYPE_INT, TYPE_NONE
        .byte   TYPE_VAR, TYPE_INT

statement_exec_vectors:
        .word   exec_list
        .word   exec_run
        .word   exec_print
        .word   exec_let

main:
        jsr     initialize_target
        jsr     initialize_program
@ready:
        jsr     print_ready
@wait_for_input:
        jsr     readline
        lda     #0                      ; Initialize read and write pointers
        sta     r
        sta     w
        jsr     skip_whitespace
        jsr     read_number             ; Leaves line number in AX and Y points to next character in buffer
        bcs     @immediate_mode
        stax    sreg
        jsr     @get_statement
        bcs     @error
        jsr     find_line_sreg
        bcs     @insert                 ; Line not found, just insert the new one
        jsr     delete_line             ; Delete the existing line
@insert:
        jsr     insert_line_sreg        ; Insert the new line
        jmp     @wait_for_input

@immediate_mode:
        jsr     @get_statement
        bcs     @error
        jsr     invoke_statement_handler
        jmp     @wait_for_input

@get_statement:
        jsr     skip_whitespace
        mvax    #statement_signature_table, signature_ptr
        ldax    #statement_name_table
        jsr     parse_element
        rts

@error:
        jsr     print_error
        jmp     @wait_for_input

; Invokes a statement handler from a table.
; This function does not return; it jumps to the handler, which will eventually return.
; A = the index of the handler in the table

invoke_statement_handler:
        tay
        ldax    #statement_exec_vectors
        jmp     invoke_indexed_vector

; Scans through the program and prints each line.

exec_list:
        jsr     reset_line_ptr
@next_line:
        jsr     update_line_fields
        ldax    line_number             ; Line number into AX
        bmi     @end                    ; If MSB of line number is set, we're at end of program
        jsr     print_number
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

; Executes the program.

exec_run:
        jsr     reset_line_ptr
@next_line:
        ldy     #1                      ; High byte of line number
        lda     (line_ptr),y
        bmi     @end                    ; If MSB of line number is set, we're at end of program
        ldy     #2                      ; Offset of line length
        lda     (line_ptr),y            ; Get length
        sta     buffer_length           ; Store in buffer_length
        sta     copy_length             ; and copy_length
        lda     #0
        sta     copy_length+1
        jsr     get_line_start          ; Start of line in AX
        sta     copy_from_ptr           ; Set source for copy
        stx     copy_from_ptr+1
        lda     #<buffer                ; Set destination for copy
        sta     copy_to_ptr
        lda     #>buffer
        sta     copy_to_ptr+1
        jsr     copy_bytes              ; Copy line into buffer
        lda     #0                      ; Start reading from offset 0
        sta     r
        lda     #<statement_name_table    ; What statement was it?
        ldx     #>statement_name_table
        jsr     find_name
        bcs     @error
        jsr     invoke_statement_handler
        jsr     advance_line_ptr
        jmp     @next_line

@error:
        jsr     print_error
@end:
        rts

exec_print:
        jsr     read_number             ; Get the number
        bcs     @error                  ; Fail if not a number
        jsr     print_number            ; Print the number
        jsr     newline
        rts

@error:
        jsr     print_error
@end:
        rts

exec_let:
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
        jsr     print_number            ; Send it right to print_number
        rts

@variable:
        and     #$7F                    ; Clear high bit leaving variable index
        tay                             ; The variable index into Y
        ldax    variable_name_table_ptr ; Look up name in the variable name table
        jsr     list_element            ; Recursively call list_element to display the name        
        rts

; Prints the number in AX to the console.

print_number:

@save_a = tmp1

        sta     @save_a                 ; Keep low byte in @save_a while we use A for other things
        lda     #0                      ; Push 0 on the stack
        pha
@next_digit:
        lda     @save_a                 ; Recover low byte
        jsr     div10                   ; Divide AX by 10
        sta     @save_a                 ; Save low byte
        tya                             ; Transfer remainder into A
        clc
        adc     #'0'
        pha                             ; Push digit
        txa                             ; High byte into A
        ora     @save_a                 ; OR with saved low byte
        bne     @next_digit             ; Still more digits
@print_digit:
        pla                             ; Get a digit
        beq     @done                   ; If it's 0 then we're done
        jsr     putchar                 ; Print it
        jmp     @print_digit

@done:
        rts

print_ready:
        lda     #<ready_message         ; Pass address of message in AX
        ldx     #>ready_message
        ldy     #ready_length
        jsr     write
        jsr     newline
        rts

; Prints an error message.

print_error:
        lda     #<error_message         ; Pass address of message in AX
        ldx     #>error_message
        ldy     #error_length
        jsr     write
        jsr     newline
        rts
