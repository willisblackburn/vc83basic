
; RUN statement:
; Executes the program.
; Perhaps surprisingly, this function does not actally set the run state. It doesn't need to, because in order for
; this handler to execute, the program must already be running. The handler just resets the program state and resumes
; execution at the first line of the program.

exec_run:
        jsr     reset_next_line_ptr
        lda     #PS_RUNNING
        jsr     reset_program

; Fall through

; CLR statement:
; Resets the runtime state of the program, but keeps the program in memory.

exec_clr:
        jsr     clear_variables
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

; NEW statment:
; Clears the program from memory, which also has the effect of stopping the program as if END.

exec_new:
        jsr     initialize_program
        clc
        rts

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
