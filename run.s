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

exec_end:
        mva     #PROGRAM_STATE_ENDED, program_state
        clc
        rts
