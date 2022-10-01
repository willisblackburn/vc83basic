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
        bcs     @error
        lda     line_buffer+Line::number+1  ; Get high byte of line number
        bmi     @immediate_mode         ; If line number is negative then we're in immediate mode
        jsr     insert_or_update_line   ; Update the program
        bcs     @error
        jmp     @wait_for_input

@immediate_mode:
        lda     line_buffer+Line::next_line_offset  ; See if there is any data in the buffer
        cmp     #Line::data             ; Does the "next line" start at the beginning of *this* line?
        beq     @wait_for_input         ; Yes, just ignore input
        ldax    #line_buffer
        jsr     set_line_ptr            ; Set line_ptr to point to line_buffer and set up line variables
        jsr     run_line
        bcs     @error
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
