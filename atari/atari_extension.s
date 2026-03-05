; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

ex_statement_name_table:
        name_table_entry "DOS"
            RETURN
:       name_table_end

ex_statement_exec_vectors:
        .word   exec_dos-1

exec_dos:
        jmp     ($A)

