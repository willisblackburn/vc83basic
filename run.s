.include "macros.inc"
.include "basic.inc"

; RUN statement:
; Executes the program.

.assert PS_RUNNING = 1, error

exec_run:
        lda     program_state
        bne     @done                   ; Don't re-run if we're already running
        jsr     reset_program_state     ; Clear the variable name table
        mva     #PS_RUNNING, program_state
@run_one_line:
        ldy     #Line::number+1         ; Position of line number high byte
        lda     (line_ptr),y            ; Into A
        bmi     @program_end            ; If MSB of line number is set, we're at end of program
        jsr     run_line
        bcs     @done
        jsr     advance_line_ptr        ; Advance to next line
        jmp     @run_one_line

@program_end:
        mva     #PS_STOPPED, program_state
        clc

@done:
        rts

; Executes the line pointed by line_ptr

run_line:
        mva     #Line::data, line_pos   ; Initialize read position to start of data
        jsr     decode_byte             ; Get statement number
        jsr     invoke_statement_handler
        rts

statement_exec_vectors:
        .word   exec_run-1
        .word   exec_print-1
        .word   exec_let-1
        .word   exec_input-1
        .word   exec_list-1

; Invokes a statement handler from a table.
; This function does not return; it jumps to the handler, which will eventually return.
; A = the index of the handler in the table

invoke_statement_handler:
        tay
        ldax    #statement_exec_vectors
        jmp     invoke_indexed_vector
