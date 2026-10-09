; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

ready_message: .byte 5, "READY"
error_message: .byte 5, "ERR: "
error_message_2: .byte 4, " AT "

; Verify that the program states are the affected values so we can use flags.

.assert PS_RUNNING = 0, error
.assert PS_READY = 1, error
.assert ERR_STOPPED = $80, error

main:
        jsr     initialize_program

raise_ps_ready:
        raise   PS_READY

; Exception handler: control reaches here following "raise."

on_raise:
        plsta   B                       ; Return address on stack points to the last byte of JSR
        plsta   C
        ldy     #1                      ; The error byte follows the JSR instruction
        lda     (BC),y
        ldx     #$FF                    ; Reset the stack pointer
        txs
        tax                             ; Update flags for new program state since STA won't do it
        sta     program_state           ; Whatever comes back from exception handler is new state
        beq     run                     ; Program is running; do the next thing
        pha                             ; Save the error value and output a newline, which we will need no matter what
        mva     #0, channel             ; Reset channel to default console (0)
        jsr     newline
        pla
        bmi     handle_error
        lday    #ready_message
        jsr     print_string
        beq     nl_get_command          ; Unconditional: print_s0 leaves Z=1

; Program is running; set line_ptr and line_pos to next statement and execute it.
; If the next statement is the end of the line, then go to the next statement. This is the *only* place where we
; move to the next line; during normal execution we can assume that next_line_ptr = line_ptr unless it has been
; modified by a control statement.

run_next_line:
        jsr     advance_next_line_ptr   ; Otherwise go to next line
run:
        ldy     #Line::next_line_offset ; Load the offset of the next line
        lda     (next_line_ptr),y
        raieq   PS_READY                ; If next line offset is 0 then end
        cmp     next_line_pos           ; Is the next line offset also the offset of the next statement?
        beq     run_next_line           ; If yes then restart from next line
        mvax    next_line_ptr, line_ptr ; Move to next statement
        mva     next_line_pos, line_pos
        jsr     get_byte                ; The next byte is the next statement offset
        sta     next_line_pos           ; By default the "next line" is the next statement on this line
        jsr     dispatch_statement
        jmp     run                     ; Keep on truckin'

handle_error:
        mvx     reset_stack_pos, stack_pos   ; After an error, restore the stack position we saved
        and     #$7F                    ; Clear the high bit
        beq     @not_error              ; For STOPPED we don't print "ERROR"
        pha                             ; Save the error value again
        lday    #error_message
        jsr     print_string
        pla     
@not_error:
        tay
        ldax    #error_message_table
        jsr     lookup_name
        mvaa    name_ptr, S0
        sec
        lda     next_name_ptr
        sbc     name_ptr
        jsr     print_s0
        ldy     #Line::number+1         ; Print line number if >= 0, else we're in immediate mode
        lda     (line_ptr),y
        bmi     nl_get_command
        lday    #error_message_2
        jsr     print_string
        jsr     print_line_number

nl_get_command:
        jsr     newline

get_command:
        ldax    #line_buffer            ; Reset next_line_ptr to line_buffer
        jsr     reset_next_line_ptr_2
        stax    line_ptr                ; Reset line_ptr too, so line number reported correctly on error
        jsr     readline
        bcc     @line_ok
.ifdef enable_io_channels
        lda     #0
        sta     channel
        jsr     close
        raise   PS_READY
.endif
@line_ok:
        tay
        lda     #0
        sta     buffer,y
        jsr     parse_line
        lda     line_buffer+Line::number+1  ; Get high byte of line number
        bmi     immediate_mode          ; If line number is negative then we're in immediate mode
        jsr     reset_program           ; Clear program line pointers
        jsr     insert_or_update_line   ; Update the program
        jmp     get_command

immediate_mode:
        lda     line_buffer+Line::next_line_offset  ; See if there is any data in the buffer
        cmp     #.sizeof(Line) + 2      ; Less than minimum line length with statement?
        bcc     get_command             ; Yes, just ignore input
        tax
        lda     #0                      ; Set next_line_offset of subsequent line to 0 to signal end of execution
        sta     line_buffer,x

raise_ps_running:
        raise   PS_RUNNING
