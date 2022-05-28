.include "target.inc"
.include "basic.inc"

.code

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
        bcs     @immediate_mode         ; No line number; execute in immediate mode
        stax    parsed_line_number
        jsr     @get_statement
        bcs     @error
        ldax    parsed_line_number
        jsr     find_line
        bcs     @insert                 ; Line not found, just insert the new one
        jsr     delete_line             ; Delete the existing line
@insert:
        ldax    parsed_line_number
        jsr     insert_line             ; Insert the new line
        jmp     @wait_for_input

@immediate_mode:
        jsr     @get_statement
        bcs     @error
        lda     line_buffer             ; Statement is in first byte of line_buffer
        jsr     invoke_statement_handler
        jmp     @wait_for_input

@get_statement:
        jsr     skip_whitespace
        mvax    #statement_signature_table, signature_ptr
        ldax    #statement_name_table
        jsr     parse_element           ; Leaves the parsed statement in line_buffer
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

; Executes the program.

exec_run:
        jsr     reset_line_ptr
@next_line:
        ldy     #1                      ; High byte of line number
        lda     (line_ptr),y
        bmi     @end                    ; If MSB of line number is set, we're at end of program
        ldy     #2                      ; Offset of line length
        lda     (line_ptr),y            ; Get length
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

; Stop-gap function...

print_number:
        mvy     #0, w
        jsr     format_number
        ldax    #buffer
        ldy     w
        jmp     write

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
