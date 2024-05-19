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
        bne     @dispatch

; Program is running; set line_ptr and line_pos to next statement and execute it.
; If the next statement is the end of the line, then go to the next statement. This is the *only* place where we
; move to the next line; during normal execution we can assume that next_line_ptr = line_ptr unless it has been
; modified by a control statement.

@next_line:
        jsr     advance_next_line_ptr   ; Otherwise go to next line
@dispatch:
        mvax    next_line_ptr, line_ptr ; Move to next statement
        mva     next_line_pos, line_pos
        ldy     #Line::next_line_offset
        cmp     (line_ptr),y            ; Is the current statement offset also the next line offset?
        beq     @next_line              ; If yes then restart from next line
        jsr     decode_byte             ; The next byte is the next statement offset
        sta     next_line_pos
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
        mvax    #line_buffer, next_line_ptr ; Set next_line_ptr to point to line_buffer
        jsr     advance_next_line_ptr   ; So we can move it to the next statement
        jsr     build_end_statement     ; Populate END statement after the immediate mode statement
        mva     #PS_RUNNING, program_state  ; Set the program state to RUNNING
        ldax    #line_buffer            ; Reset next_line_ptr to line_buffer
        jsr     reset_next_line_ptr_to
        bne     @dispatch               ; Unconditional

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
        tay                             ; Park low byte
        lda     himem_ptr+1
        sbc     free_ptr+1
        tax                             ; High byte in X
        tya                             ; Low byte back into A
        jsr     int_to_fp               ; Load into FP0
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
