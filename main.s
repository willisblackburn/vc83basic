; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

start_message: .byte "VC83 BASIC <> "
start_length = * - start_message

free_message: .byte " BYTES FREE"
free_length = * - free_message

ready_message: .byte "READY"
ready_message_length = * - ready_message
error_message: .byte "ERROR"
error_message_length = * - error_message

; Verify that the program states are the affected values so we can use flags.

.assert PS_STOPPED = 0, error
.assert PS_RUNNING = 1, error

main:
        jsr     initialize_target
        jsr     initialize_program
        jsr     print_start
@loop:
        lda     program_state
        beq     @get_command

; Program is running; set line_ptr and execute statement.

        ldy     #Line::next_line_offset ; Load the offset of the next line
        lda     (next_line_ptr),y
        beq     @end                    ; If next line offset is 0 then end
        mvax    next_line_ptr, line_ptr ; Get the next line to run
        jsr     advance_next_line_ptr   ; Move next_line_ptr to following line

; Reads the statement from line_ptr and dispatch to a handler.

@dispatch:
        mva     #.sizeof(Line), line_pos    ; Initialize read position to start of data
        jsr     exec_statement
        bcc     @loop
@error:
        jsr     print_error
        jsr     exec_stop
        bcc     @loop                   ; Unconditional

@end:
        mva     #PS_STOPPED, program_state
@get_command:
        jsr     print_ready
@wait_for_input:
        jsr     readline
        jsr     parse_line
        bcs     @error
        lda     line_buffer+Line::number+1  ; Get high byte of line number
        bmi     @immediate_mode         ; If line number is negative then we're in immediate mode
        mva     #0, resume_line_ptr+1   ; Clear high byte of resume_line_ptr to disable CONT
        jsr     insert_or_update_line   ; Update the program
        bcs     @error
        bcc     @wait_for_input

@immediate_mode:
        lda     line_buffer+Line::next_line_offset  ; See if there is any data in the buffer
        cmp     #.sizeof(Line)          ; Does the "next line" start at the beginning of *this* line?
        beq     @wait_for_input         ; Yes, just ignore input
        ldx     #>line_buffer           ; High byte of the address for the the null line
        jsr     append_null_line
        mvax    #line_buffer, line_ptr  ; Set line_ptr to point to line_buffer    
        stax    next_line_ptr           ; And next_line_ptr
        jsr     advance_next_line_ptr   ; Tee up next line

        mva     #PS_RUNNING, program_state  ; Set the program state to RUNNING
        bne     @dispatch               ; Unconditional; Decodes and executes one statement from the token stream.

; Decodes and executes one statement from the token stream.

exec_statement:
        jsr     decode_byte             ; Get statement number
        tay
        ldax    #statement_exec_vectors
        jmp     invoke_indexed_vector

statement_exec_vectors:
        .word   exec_end-1
        .word   exec_run-1
        .word   exec_print-1
        .word   exec_let-1
        .word   exec_input-1
        .word   exec_list-1
        .word   exec_goto-1
        .word   exec_gosub-1
        .word   exec_return-1
        .word   exec_pop-1
        .word   exec_on_goto-1
        .word   exec_on_gosub-1
        .word   exec_for-1
        .word   exec_next-1
        .word   exec_stop-1
        .word   exec_cont-1
        .word   exec_if-1

print_start:
        ldax    #start_message
        ldy     #start_length
        jsr     write
        sec                             ; Calculate free memory; TODO: move to FRE function
        lda     himem_ptr
        sbc     free_ptr
        tay
        lda     himem_ptr+1
        sbc     free_ptr+1
        tax
        tya
        jsr     print_number
        ldax    #free_message
        ldy     #free_length
        jsr     write
        jmp     newline

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
