.include "basic.inc"

statement_name_table:
        .byte   'R', 'U', 'N' | NT_END
        .byte   'P', 'R', 'I', 'N', 'T', NT_EXPRESSION | NT_END
        .byte   'L', 'E', 'T', NT_VAR, '=', NT_EXPRESSION | NT_END
        .byte   'I', 'N', 'P', 'U', 'T', NT_RPT_VAR | NT_END
        .byte   'L', 'I', 'S', 'T', 2 | NT_OPTIONAL | NT_END
        .byte   0

operator_name_table:
        .byte '+' | NT_END
        .byte '-' | NT_END
        .byte '*' | NT_END
        .byte '/' | NT_END
        .byte '^' | NT_END
        .byte '&' | NT_END
        .byte '=' | NT_END
        .byte '<', '>' | NT_END
        .byte '<', '=' | NT_END
        .byte '<' | NT_END
        .byte '>', '=' | NT_END
        .byte '>' | NT_END
        .byte 'A', 'N', 'D' | NT_END
        .byte 'O', 'R' | NT_END
        .byte 0

misc_name_table:
        .byte '(' | NT_END
        .byte ')' | NT_END
        .byte 'N', 'O', 'T' | NT_END
        .byte '-' | NT_END
        .byte ',' | NT_END
        .byte ';' | NT_END
        .byte 0
