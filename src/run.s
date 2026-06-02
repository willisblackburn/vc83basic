; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

; RUN statement:
; Executes the program.
; Perhaps surprisingly, this function does not actally set the run state. It doesn't need to, because in order for
; this handler to execute, the program must already be running. The handler just resets the program state and resumes
; execution at the first line of the program.

exec_run:
        jsr     reset_program
        jsr     reset_next_line_ptr
        jsr     clear_variables
        jmp     raise_ps_running

; END statement:
; Terminates the program.

exec_end:
        mva     #0, resume_line_ptr+1   ; Disable CONT
        jmp     raise_ps_ready

; STOP statement:
; Stops the program (can be resumed with CONT).

exec_stop:
        lda     next_line_ptr+1         ; Check if we're running in immediate mode
        cmp     #>line_buffer
        beq     @stopped                ; STOP in immdiate mode just does nothing
        sta     resume_line_ptr+1
        mva     next_line_ptr, resume_line_ptr  ; Note mva not mvaa
        mva     next_line_pos, resume_line_pos
@stopped:
        raise   ERR_STOPPED

; CONT statement:
; Continues the program after STOP.

exec_cont:
        mvaa    resume_line_ptr, next_line_ptr
        raieq   ERR_CONT_WITHOUT_STOP
        mva     resume_line_pos, next_line_pos
        jmp     raise_ps_running

; NEW statment:
; Clears the program from memory, which also has the effect of stopping the program as if END.

exec_new:
        jsr     initialize_program
        clc
        rts
