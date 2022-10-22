.include "macros.inc"
.include "basic.inc"

; RUN statement:
; Executes the program.

exec_run:
        jsr     reset_program_state     ; Clear the variable name table
exec_run_no_reset:
        mva     #PROGRAM_STATE_RUNNING, program_state
        clc
        rts

exec_end:
        mva     #PROGRAM_STATE_ENDED, program_state
        clc
        rts

; Executes the line pointed by line_ptr

run_line:
        mva     #Line::data, lp         ; Initialize read position to start of data
        jsr     decode_byte             ; Get statement number
        jsr     invoke_statement_handler
        rts

statement_exec_vectors:
        .word   exec_end
        .word   exec_run
        .word   exec_print
        .word   exec_let
        .word   exec_input
        .word   exec_list
        .word   exec_goto

; Invokes a statement handler from a table.
; This function does not return; it jumps to the handler, which will eventually return.
; A = the index of the handler in the table

invoke_statement_handler:
        tay
        ldax    #statement_exec_vectors
        jmp     invoke_indexed_vector
