.include "macros.inc"
.include "basic.inc"

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

        mvax    next_line_ptr, line_ptr ; Get the next line to run
        jsr     advance_next_line_ptr   ; Move next_line_ptr to following line

; Reads the statement from line_ptr and dispatch to a handler.

@dispatch:
        mva     #Line::data, line_pos   ; Initialize read position to start of data
        jsr     dispatch_statement
        bcc     @loop
@error:
        jsr     print_error
        jsr     exec_stop
        bcc     @loop

@get_command:
        jsr     print_ready
@wait_for_input:
        jsr     readline
        jsr     parse_line
        bcs     @error
        lda     line_buffer+Line::number+1  ; Get high byte of line number
        bmi     @immediate_mode         ; If line number is negative then we're in immediate mode
        mva     #0, resume_line_ptr+1   ; Clear high byte of resume line_ptr to disable CONT
        jsr     insert_or_update_line   ; Update the program
        bcs     @error
        bcc     @wait_for_input

@immediate_mode:
        lda     line_buffer+Line::next_line_offset  ; See if there is any data in the buffer
        cmp     #Line::data             ; Does the "next line" start at the beginning of *this* line?
        beq     @wait_for_input         ; Yes, just ignore input
        mvax    #line_buffer, line_ptr  ; Set line_ptr to point to line_buffer    
        stax    next_line_ptr           ; And next_line_ptr
        jsr     advance_next_line_ptr   ; So we can move it to the next statement
        jsr     build_end_statement     ; Populate END statement after the immediate mode statement
        mva     #PS_RUNNING, program_state  ; Set the program state to RUNNING
        bne     @dispatch

; Decodes and executes one statement from the token stream.

dispatch_statement:
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
