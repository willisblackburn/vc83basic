; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

start_message: .byte "VC83 BASIC <> "
start_length = * - start_message

free_message: .byte " BYTES FREE"
free_length = * - free_message

ready_message: .byte "READY"
ready_message_length = * - ready_message

error_message: .byte "ERROR: "
error_message_length = * - error_message

error_message_2: .byte " AT "
error_message_2_length = * - error_message_2

; Verify that the program states are the affected values so we can use flags.

.assert PS_RUNNING = 0, error
.assert PS_READY = 1, error
.assert ERR_STOPPED = $80, error

main:
        jsr     initialize_target
        jsr     initialize_program
        jsr     print_start
        tsx                             ; Remember the stack pointer so we can return to main later
        stx     exception_handler_sp
        lda     #PS_READY               ; Will be passed through install_exception_handler
        jsr     install_exception_handler

; Exception handler: control reaches here following "raise" or JMP to on_raise.

        sta     program_state           ; Whatever comes back from exception handler is new state
        beq     @dispatch               ; Program is running; do the next thing
        pha                             ; Save the error value and output a newline, which we will need no matter what
        jsr     newline
        pla
        bmi     @error
        ldax    #ready_message
        ldy     #ready_message_length
        jsr     write
        jsr     newline

@get_command:
        jsr     readline
        jsr     parse_line
        bcs     @error
        lda     line_buffer+Line::number+1  ; Get high byte of line number
        bmi     @immediate_mode         ; If line number is negative then we're in immediate mode
        jsr     reset_program           ; Clear program line pointers
        jsr     insert_or_update_line   ; Update the program
        jmp     @get_command

@immediate_mode:
        lda     line_buffer+Line::next_line_offset  ; See if there is any data in the buffer
        cmp     #.sizeof(Line)          ; Does the "next line" start at the beginning of *this* line?
        beq     @get_command            ; Yes, just ignore input
        ldx     #>line_buffer           ; High byte of the address for the the null line
        jsr     append_null_line
        ldax    #line_buffer            ; Reset next_line_ptr to line_buffer
        jsr     reset_next_line_ptr_2
        raise   PS_RUNNING

; Program is running; set line_ptr and line_pos to next statement and execute it.
; If the next statement is the end of the line, then go to the next statement. This is the *only* place where we
; move to the next line; during normal execution we can assume that next_line_ptr = line_ptr unless it has been
; modified by a control statement.

@next_line:
        jsr     advance_next_line_ptr   ; Otherwise go to next line
@dispatch:
        ldy     #Line::next_line_offset ; Load the offset of the next line
        lda     (next_line_ptr),y
        raieq   PS_READY                ; If next line offset is 0 then end
        cmp     next_line_pos           ; Is the next line offset also the offset of the next statement?
        beq     @next_line              ; If yes then restart from next line
        mvax    next_line_ptr, line_ptr ; Move to next statement
        mva     next_line_pos, line_pos
        jsr     decode_byte             ; The next byte is the next statement offset
        sta     next_line_pos           ; By default the "next line" is the next statement on this line
        jsr     exec_statement
        mva     stack_pos, good_stack_pos   ; Remember the stack position after successful statement
        jmp     @dispatch               ; Keep on truckin'

@error:
        mvx     good_stack_pos, stack_pos   ; After an error, restore the stack position we saved
        and     #$7F                    ; Clear the high bit
        beq     @not_error              ; For STOPPED we don't print "ERROR"
        pha                             ; Save the error value again
        ldax    #error_message
        ldy     #error_message_length
        jsr     write
        pla     
@not_error:
        tay                             ; Prepare to look up the program_state message
        ldax    #error_message_table
        jsr     get_name
        sec
        lda     next_name_ptr           ; Length of message is next_name_ptr - name_ptr
        sbc     name_ptr
        tay
        ldax    name_ptr
        jsr     write
        ldy     #Line::number+1         ; Print line number if >= 0, else we're in immediate mode
        lda     (line_ptr),y
        bmi     @no_line_number
        ldax    #error_message_2
        ldy     #error_message_2_length
        jsr     write
        mva     #0, buffer_pos
        jsr     line_number_to_string
        ldy     buffer_pos
        ldax    #buffer
        jsr     write
@no_line_number:
        jsr     newline
        jmp     @get_command

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
        .word   exec_new-1
        .word   exec_clr-1
        .word   exec_dim-1
        .word   exec_rem-1
        .word   exec_data-1
        .word   exec_read-1
        .word   exec_restore-1
        .word   exec_poke-1

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
