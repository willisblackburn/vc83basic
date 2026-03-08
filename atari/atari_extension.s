; SPDX-FileCopyrightText: 2026 Willis Blackburn and Daniel Serpell
;
; SPDX-License-Identifier: MIT

.segment "PARSER"

ex_statement_name_table:
        name_table_entry "DOS"
            RETURN
:       name_table_end

ex_function_name_table:
        name_table_end

.code

ex_statement_vectors:
        .word   exec_dos-1

exec_dos:
        jmp     (DOSVEC)

ex_function_arity_table:

ex_function_vectors:
