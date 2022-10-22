.include "macros.inc"
.include "basic.inc"

start_message: .byte "VC83 BASIC <> "
start_length = * - start_message

free_message: .byte " BYTES FREE"
free_length = * - free_message

ready_message: .byte "READY"
ready_length = * - ready_message

error_message: .byte "ERROR"
error_length = * - error_message

; Verify that the program states are the affected values so we can use flags.

.assert PROGRAM_STATE_RUNNING = 0, error

main:
        jsr     initialize_target
        jsr     initialize_program
        jsr     print_start
@ready:
        jsr     print_ready
@loop:
        lda     program_state
        bne     @get_command
        mvax    next_line_ptr, line_ptr ; Get the next line to run
        jsr     advance_next_line_ptr   ; Move next_line_ptr to following line
        jsr     run_line
        bcc     @loop
@error:
        jsr     print_error
        mva     #PROGRAM_STATE_STOPPED, program_state
        bne     @loop

@end:
        mva     #PROGRAM_STATE_ENDED, program_state
        bne     @ready

@get_command:
        jsr     readline
        jsr     parse_line
        bcs     @error
        lda     line_buffer+Line::number+1  ; Get high byte of line number
        bmi     @immediate_mode         ; If line number is negative then we're in immediate mode
        jsr     insert_or_update_line   ; Update the program
        bcs     @error
        jmp     @loop

@immediate_mode:
        lda     line_buffer+Line::next_line_offset  ; See if there is any data in the buffer
        cmp     #Line::data             ; Does the "next line" start at the beginning of *this* line?
        beq     @loop                   ; Yes, just ignore input
        tay                             ; Move next_line_offset to Y as starting point for END statement
        mvax    #line_buffer, next_line_ptr ; Set next_line_ptr to point to line_buffer
        jsr     build_end_statement     ; Populate END statement after the immediate mode statement
        jsr     exec_run_no_reset
        jmp     @loop

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
        ldy     #ready_length
        jsr     write
        jmp     newline

; Prints an error message.

print_error:
        ldax    #error_message          ; Pass address of message in AX
        ldy     #error_length
        jsr     write
        jmp     newline
