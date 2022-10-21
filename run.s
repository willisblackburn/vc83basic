.include "macros.inc"
.include "basic.inc"

; RUN statement:
; Executes the program.

exec_run:
        lda     program_state
        cmp     #PROGRAM_STATE_RUNNING  ; Don't re-run if we're already running
        beq     @done                   ; Carry will be set on equal
        jsr     reset_program_state     ; Clear the variable name table
        mva     #PROGRAM_STATE_RUNNING, program_state
@run_one_line:
        ldy     #Line::number+1         ; Position of line number high byte
        lda     (line_ptr),y            ; Into A
        bmi     @program_end            ; If MSB of line number is set, we're at end of program
        jsr     run_line
        bcs     @done
        jsr     advance_line_ptr        ; Advance to next line
        jmp     @run_one_line

@program_end:
        mva     #PROGRAM_STATE_ENDED, program_state
        clc

@done:
        rts

; Executes the line pointed by line_ptr

run_line:
        mva     #Line::data, lp         ; Initialize read position to start of data
        jsr     decode_byte             ; Get statement number
        jsr     invoke_statement_handler
        rts

statement_exec_vectors:
        .word   exec_run
        .word   exec_print
        .word   exec_let
        .word   exec_input
        .word   exec_list

; Invokes a statement handler from a table.
; This function does not return; it jumps to the handler, which will eventually return.
; A = the index of the handler in the table

invoke_statement_handler:
        tay
        ldax    #statement_exec_vectors
        jmp     invoke_indexed_vector
