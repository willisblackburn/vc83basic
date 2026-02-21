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
        bne     @dispatch

; Program is running; set line_ptr and line_pos to next statement and execute it.
; If the next statement is the end of the line, then go to the next statement. This is the *only* place where we
; move to the next line; during normal execution we can assume that next_line_ptr = line_ptr unless it has been
; modified by a control statement.

@next_line:
        jsr     advance_next_line_ptr   ; Otherwise go to next line
@dispatch:
        ldy     #Line::next_line_offset ; Load the offset of the next line
        lda     (next_line_ptr),y
        beq     @end                    ; If next line offset is 0 then end
        cmp     next_line_pos           ; Is the next line offset also the offset of the next statement?
        beq     @next_line              ; If yes then restart from next line
        mvax    next_line_ptr, line_ptr ; Move to next statement
        mva     next_line_pos, line_pos
        jsr     decode_byte             ; The next byte is the next statement offset
        sta     next_line_pos           ; By default the "next line" is the next statement on this line
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
        jsr     reset_program_stopped   ; Clear program line pointers
        jsr     insert_or_update_line   ; Update the program
        bcs     @error
        bcc     @wait_for_input

@immediate_mode:
        lda     line_buffer+Line::next_line_offset  ; See if there is any data in the buffer
        cmp     #.sizeof(Line)          ; Does the "next line" start at the beginning of *this* line?
        beq     @wait_for_input         ; Yes, just ignore input
        ldx     #>line_buffer           ; High byte of the address for the the null line
        jsr     append_null_line
        mva     #PS_RUNNING, program_state  ; Set the program state to RUNNING
        ldax    #line_buffer            ; Reset next_line_ptr to line_buffer
        jsr     reset_next_line_ptr_2
        bne     @dispatch               ; Unconditional



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
