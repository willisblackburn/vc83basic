.include "basic.inc"

statement_name_table:
        .byte   'R', 'U', 'N' | NT_END
        .byte   'P', 'R', 'I', 'N', 'T', 1 | NT_END
        .byte   'L', 'E', 'T', NT_VAR, '=', 1 | NT_END
        .byte   0
