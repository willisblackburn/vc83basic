.include "macros.inc"
.include "basic.inc"

.zeropage

; Where to resume execution after STOP
resume_line_ptr: .res 2

; Position of resume statement
resume_lp: .res 1

.code

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
        mva     next_lp, resume_lp
        mva     #PS_STOPPED, program_state
        clc
        rts

; CONT statement:
; Continues the program after STOP.

exec_cont:
        sec                             ; Set in case we take this next branch
        mvaa    resume_line_ptr, next_line_ptr
        mva     resume_lp, next_lp
        beq     @done                   ; Can't resume because high byte of resume_line_ptr is 0
        mva     #PS_RUNNING, program_state
        clc
@done:
        rts
