; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

.segment "PARSER"

ex_statement_name_table:
        name_table_entry "GR"
            RETURN
:       name_table_entry "TEXT"
            RETURN
:       name_table_end

ex_function_name_table:
        name_table_entry "PDL"
:       name_table_end

.segment "VECTORS"

ex_statement_vectors:
        .word   exec_gr-1
        .word   exec_text-1

.code

exec_gr:
        jsr     SETGR
        rts

exec_text:
        jsr     SETTXT
        rts

ex_function_arity_table:
        .byte   1                       ; PDL

.segment "VECTORS"

ex_function_vectors:
        .word   fun_pdl-1

.code

fun_pdl:
        jsr     pop_int_fp0
        jsr     PREAD                   ; Returns result in Y
        tya
        ldx     #0
        jmp     push_int_fp0
