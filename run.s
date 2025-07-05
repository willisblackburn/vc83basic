.include "macros.inc"
.include "basic.inc"

; RUN statement:
; Executes the program.

exec_run:
        jsr     reset_program_state     ; Clear the variable name table
        clc
        rts

; END statement:
; Terminates the program.

.assert PS_STOPPED = 0, error

exec_end:
        mva     #PS_STOPPED, program_state
        sta     resume_line_ptr+1       ; Disable CONT
        clc
        rts

; STOP statement:
; Stops the program (can be resumed with CONT).

exec_stop:
        mvaa    next_line_ptr, resume_line_ptr
        mva     #PS_STOPPED, program_state
        clc
        rts

; CONT statement:
; Continues the program after STOP.

exec_cont:
        sec                             ; Set in case we take this next branch
        mvaa    resume_line_ptr, next_line_ptr
        beq     @done                   ; Can't resume because high byte of resume_line_ptr is 0
        mva     resume_line_pos, next_line_pos
        mva     #PS_RUNNING, program_state
        clc
@done:
        rts
