.include "basic.inc"

statement_name_table:
        .byte   'L', 'I', 'S', 'T' | NT_END
        .byte   'R', 'U', 'N' | NT_END
        .byte   'P', 'R', 'I', 'N', 'T', 1 | NT_END
        .byte   'L', 'E', 'T', 1, '=', 1 | NT_END
        .byte   'I', 'N', 'P', 'U', 'T', 1 | NT_END
        .byte   'D', 'A', 'T', 'A', 1 | NT_END
        .byte   'R', 'E', 'A', 'D', 1 | NT_END
        .byte   'R', 'E', 'S', 'T', 'O', 'R', 'E', 1 | NT_END
        .byte   0

statement_signature_table:
        .byte   TYPE_NONE, TYPE_NONE
        .byte   TYPE_NONE, TYPE_NONE
        .byte   TYPE_INT, TYPE_NONE
        .byte   TYPE_VAR, TYPE_INT
        .byte   TYPE_VAR, TYPE_NONE
        .byte   TYPE_INT | TYPE_REPEATED, TYPE_NONE
        .byte   TYPE_VAR | TYPE_REPEATED, TYPE_NONE
        .byte   TYPE_INT, TYPE_NONE

statement_exec_vectors:
        .word   exec_list
        .word   exec_run
        .word   exec_print
        .word   exec_let
        .word   exec_input
        .word   exec_data
        .word   exec_read
        .word   exec_restore
