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

.segment "VECTORS"

ex_statement_vectors:
        .word   exec_dos-1

.code

exec_dos:
        jmp     (DOSVEC)

ex_function_arity_table:

.segment "VECTORS"

ex_function_vectors:

.code
