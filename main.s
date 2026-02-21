; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

ready_message: .byte "READY"
ready_message_length = * - ready_message
error_message: .byte "ERROR"
error_message_length = * - error_message

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
        bcc     @wait_for_input

@immediate_mode:
        lda     line_buffer+Line::next_line_offset  ; See if there is any data in the buffer
        cmp     #.sizeof(Line)          ; Does the "next line" start at the beginning of *this* line?
        beq     @wait_for_input         ; Yes, just ignore input
        mvax    #line_buffer, line_ptr  ; Set line_ptr to point to line_buffer
        jsr     run_line
        bcc     @ready

@error:
        jsr     print_error
        jmp     @wait_for_input

; Executes the line pointed by line_ptr

run_line:
        mva     #.sizeof(Line), line_pos    ; Initialize read position to start of data
        jsr     decode_byte             ; Get statement number
        jsr     invoke_statement_handler
        rts

statement_exec_vectors:
        .word   exec_run-1
        .word   exec_print-1
        .word   exec_let-1

; Invokes a statement handler from a table.
; This function does not return; it jumps to the handler, which will eventually return.
; A = the index of the handler in the table

invoke_statement_handler:
        tay
        ldax    #statement_exec_vectors
        jmp     invoke_indexed_vector

print_ready:
        jsr     newline
        ldax    #ready_message          ; Pass address of message in AX
        ldy     #ready_message_length   ; Message length
        jsr     write
        jmp     newline

; Prints an error message.

print_error:
        ldax    #error_message          ; Pass address of message in AX
        ldy     #error_message_length   ; Message length
        jsr     write
        jmp     newline
