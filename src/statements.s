; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

; Decodes and executes one statement from the token stream.

.assert TOKEN_EXTENSION = $80, error

.assert ex_statement_vectors_offset >= statement_vectors_offset, error

exec_statement:
        jsr     decode_byte             ; Get statement number
        clc
        adc     #statement_vectors_offset
        bpl     @core                   ; It's a core statement not extension
        sbc     #(TOKEN_EXTENSION - ex_statement_vectors_offset + statement_vectors_offset - 1) ; -1 b/c carry clear
@core:
        jmp     invoke_indexed_vector

.segment "VEC"

statement_vectors:
        .word   exec_let-1
        .word   exec_let-1
        .word   exec_run-1
        .word   exec_print-1
        .word   exec_print-1
        .word   exec_list-1
        .word   exec_goto-1
        .word   exec_goto-1
        .word   exec_gosub-1
        .word   exec_return-1
        .word   exec_pop-1
        .word   exec_on_goto_gosub-1
        .word   exec_for-1
        .word   exec_next-1
        .word   exec_stop-1
        .word   exec_cont-1
        .word   initialize_program-1
        .word   clear_variables-1
        .word   exec_dim-1
        .word   exec_rem-1
        .word   exec_data-1
        .word   exec_read-1
        .word   exec_restore-1
        .word   exec_poke-1
        .word   exec_dpoke-1
        .word   exec_end-1
        .word   exec_input-1
        .word   exec_if-1

.code
