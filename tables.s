.include "basic.inc"

statement_name_table:
        .byte   'R', 'U', 'N' | NT_END
        .byte   'P', 'R', 'I', 'N', 'T', 1 | NT_END
        .byte   'L', 'E', 'T', 1, '=', 1 | NT_END
        .byte   'I', 'N', 'P', 'U', 'T', NT_RPT_VAR | NT_END
        .byte   0

statement_exec_vectors:
        .word   exec_run
        .word   exec_print
        .word   exec_let
        .word   exec_input
