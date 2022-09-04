.include "basic.inc"

statement_name_table:
        .byte   'R', 'U', 'N' | NT_END
        .byte   'P', 'R', 'I', 'N', 'T', NT_EXP | NT_END
        .byte   'L', 'E', 'T', NT_VAR, '=', NT_EXP | NT_END
        .byte   0
