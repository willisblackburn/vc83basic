.include "basic.inc"

statement_name_table:
        .byte   'R', 'U', 'N' | NT_END
        .byte   'P', 'R', 'I', 'N', 'T', NT_EXPRESSION | NT_END
        .byte   'L', 'E', 'T', NT_VAR, '=', NT_EXPRESSION | NT_END
        .byte   'I', 'N', 'P', 'U', 'T', NT_RPT_VAR | NT_END
        .byte   0
