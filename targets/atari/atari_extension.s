; SPDX-FileCopyrightText: 2026 Willis Blackburn and Daniel Serpell
;
; SPDX-License-Identifier: MIT

.segment "PARSER"

ex_statement_name_table:
        name_table_entry "DOS"
:       name_table_end

ex_function_name_table:
        name_table_end

.segment "XVEC"

ex_statement_vectors:
        .word   exec_dos-1

.code

exec_dos:
        jmp     (DOSVEC)

.segment "XFUNC"

ex_function_table:

.code
