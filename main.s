; cc65 runtime
.include "zeropage.inc"

.include "target.inc"
.include "basic.inc"

ready_message: .byte "READY"
ready_length = * - ready_message

error_message: .byte "ERROR"
error_length = * - error_message

statement_name_table:
        .byte   'L', 'I', 'S', 'T' | NT_END_OF_ENTRY
        .byte   'R', 'U', 'N', NT_1ARG | NT_END_OF_ENTRY
        .byte   'P', 'R', 'I', 'N', 'T', NT_1ARG | NT_END_OF_ENTRY
        .byte   0

statement_signature_table:
        .byte   TYPE_INT | TYPE_OPTIONAL, TYPE_INT | TYPE_OPTIONAL
        .byte   TYPE_INT | TYPE_OPTIONAL, TYPE_NONE
        .byte   TYPE_INT | TYPE_OPTIONAL

statement_exec_vectors:
        .word   exec_list
        .word   exec_run
        .word   exec_print

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

; Outputs a syntax element.
; AX = pointer to the first entry in the name table
; Y = the index of the syntax element

list_element:

@save_y = tmp3
@last = tmp4

        jsr     get_name_table_entry    ; Sets name_ptr
        ldy     #0                      ; Start at position 0
@next_char:
        lda     (name_ptr),y            ; Load the character
        sta     @last                   ; Remember it
        iny                             ; Next position
        sty     @save_y
        and     #$60                    ; Is it a literal?
        beq     @handle_arguments       ; Nope
        lda     @last                   ; Load character again
        and     #$7F                    ; Clear high bit if set
        jsr     putchar                 ; Print the character

@loop:
        ldy     @save_y
        lda     @last                   ; Character again
        bpl     @next_char              ; Next character
        rts                             ; High bit is set; end of name table entry

@handle_arguments:
        lda     #' '                    ; Print a space
        jsr     putchar
        lda     @last                   ; Get the last character again
        and     #$0F                    ; Number of arguments
        jsr     list_arguments          ; List them
        jmp     @loop

; Prints statement or function arguments from the token stream.
; Unlike parse_arguments, this function does not use the signature table. Instead, we just print arguments using
; the types in the token stream.
; r = read position in token stream (updated) 

list_arguments:

@argument_count = tmp2

        sta     @argument_count         ; Save the argument count
        ldy     r                       ; Load read position into Y
@next_argument:

        lda     #'0'                    ; Just output 0 for each one
        jsr     putchar
        dec     @argument_count
        beq     @done
        lda     #','
        jsr     putchar
        jmp     @next_argument
@done:
        stx     r
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
