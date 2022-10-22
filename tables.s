.include "basic.inc"

statement_name_table:
        .byte   'E', 'N', 'D' | NT_END
        .byte   'R', 'U', 'N' | NT_END
        .byte   'P', 'R', 'I', 'N', 'T', 1 | NT_END
        .byte   'L', 'E', 'T', NT_VAR, '=', 1 | NT_END
        .byte   'I', 'N', 'P', 'U', 'T', NT_RPT_VAR | NT_END
        .byte   'L', 'I', 'S', 'T', 2 | NT_END
        .byte   'G', 'O', 'T', 'O', NT_NUM | NT_END
        .byte   'G', 'O', 'S', 'U', 'B', NT_NUM | NT_END
        .byte   'R', 'E', 'T', 'U', 'R', 'N' | NT_END
        .byte   'P', 'O', 'P' | NT_END
        .byte   'O', 'N', 1, 'G', 'O', 'T', 'O', NT_RPT_NUM | NT_END
        .byte   'O', 'N', 1, 'G', 'O', 'S', 'U', 'B', NT_RPT_NUM | NT_END
        .byte   0

operator_name_table:
        .byte   '+' | NT_END
        .byte   '-' | NT_END
        .byte   '*' | NT_END
        .byte   '/' | NT_END
        .byte   '^' | NT_END
        .byte   '&' | NT_END
        .byte   '=' | NT_END
        .byte   '<', '>' | NT_END
        .byte   '<', '=' | NT_END
        .byte   '<' | NT_END
        .byte   '>', '=' | NT_END
        .byte   '>' | NT_END
        .byte   'A', 'N', 'D' | NT_END
        .byte   'O', 'R' | NT_END
        .byte   0

; Operator precedence table
; We index this by the operator index divided by 2.

operator_precedence_table:
        .byte   PR_ADD          ; +, -
        .byte   PR_MUL          ; *, /
        .byte   PR_POW          ; ^, &
        .byte   PR_RELATIONAL   ; =, <>
        .byte   PR_RELATIONAL   ; <=, <
        .byte   PR_RELATIONAL   ; >=, >
        .byte   PR_LOGICAL      ; AND, OR

unary_operator_name_table:
        .byte   '-' | NT_END
        .byte   'N', 'O', 'T' | NT_END
        .byte   0
