.include "basic.inc"

statement_name_table:
        .byte   'R', 'U', 'N' | NT_END
        .byte   'P', 'R', 'I', 'N', 'T', 1 | NT_END
        .byte   'L', 'E', 'T', NT_VAR, '=', 1 | NT_END
        .byte   'I', 'N', 'P', 'U', 'T', NT_RPT_VAR | NT_END
        .byte   'L', 'I', 'S', 'T', 2 | NT_END
        .byte   0

operator_name_table:
operator_chars:
        .byte   '+' | NT_END
        .byte   '-' | NT_END
        .byte   '*' | NT_END
        .byte   '/' | NT_END
        .byte   '^' | NT_END
operator_chars_end:
        .byte   0

unary_operator_name_table:
        .byte   '-' | NT_END
        .byte   0
