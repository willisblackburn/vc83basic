; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

; RUN statement:
; Executes the program.

.assert PS_RUNNING = 1, error

exec_run:
        lda     program_state
        bne     @done                   ; Don't re-run if we're already running
        jsr     reset_program_state     ; Clear the variable name table
        mva     #PS_RUNNING, program_state
@run_one_line:
        ldy     #Line::next_line_offset ; Position of next line offset
        lda     (line_ptr),y            ; Into A
        beq     @end                    ; If zero, we're at end of program
        jsr     run_line
        bcs     @done
        jsr     advance_line_ptr        ; Advance to next line
        jmp     @run_one_line

@end:
        mva     #PS_STOPPED, program_state
        clc

@done:
        rts
