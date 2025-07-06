.include "macros.inc"
.include "basic.inc"

; RUN statement:
; Executes the program.

exec_run:
        jsr     reset_next_line_ptr
        jsr     reset_program_state
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
        lda     next_line_ptr+1         ; Check if we're running in immediate mode
        cmp     #>line_buffer
        beq     @error                  ; If equal then return with carry set
        sta     resume_line_ptr+1
        mva     next_line_ptr, resume_line_ptr  ; Note mva not mvaa
        mva     next_line_pos, resume_line_pos
        mva     #PS_STOPPED, program_state
        clc
@error:
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
