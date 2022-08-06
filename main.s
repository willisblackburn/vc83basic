.include "macros.inc"
.include "basic.inc"

ready_message: .byte "READY"
ready_length = * - ready_message

error_message: .byte "ERROR"
error_length = * - error_message

main:
        jsr     initialize_target
        jsr     initialize_program
@ready:
        jsr     print_ready
@wait_for_input:
        jsr     readline
        jsr     parse_line
        lda     line_buffer+Line::number+1  ; Get high byte of line number
        bmi     @immediate_mode         ; If line number is negative then we're in immediate mode
        jsr     insert_or_update_line   ; Update the program
        jmp     @wait_for_input

@immediate_mode:
        lda     line_buffer+Line::data  ; Statement is in line_buffer.data
        jsr     invoke_statement_handler
        jmp     @wait_for_input

@error:
        jsr     print_error
        jmp     @wait_for_input

print_ready:
        ldax    #ready_message          ; Pass address of message in AX
        ldy     #ready_length
        jsr     write
        jmp     newline

; Prints an error message.

print_error:
        ldax    #error_message          ; Pass address of message in AX
        ldy     #error_length
        jsr     write
        jmp     newline
