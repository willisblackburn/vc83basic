.include "basic.inc"

statement_name_table:
        .byte   :+ - *, 'E', 'N', 'D' | NT_STOP
:       .byte   :+ - *, 'R', 'U', 'N' | NT_STOP
:       .byte   :+ - *, 'P', 'R', 'I', 'N', 'T' | NT_STOP, 1
:       .byte   :+ - *, 'L', 'E', 'T' | NT_STOP, NT_VAR, '=', 1
:       .byte   :+ - *, 'I', 'N', 'P', 'U', 'T' | NT_STOP, NT_RPT_VAR
:       .byte   :+ - *, 'L', 'I', 'S', 'T' | NT_STOP, 2
:       .byte   :+ - *, 'G', 'O', 'T', 'O' | NT_STOP, NT_NUM
:       .byte   :+ - *, 'G', 'O', 'S', 'U', 'B' | NT_STOP, NT_NUM
:       .byte   :+ - *, 'R', 'E', 'T', 'U', 'R', 'N' | NT_STOP
:       .byte   :+ - *, 'P', 'O', 'P' | NT_STOP
:       .byte   :+ - *, 'O', 'N' | NT_STOP, 1, 'G', 'O', 'T', 'O', NT_RPT_NUM
:       .byte   :+ - *, 'O', 'N' | NT_STOP, 1, 'G', 'O', 'S', 'U', 'B', NT_RPT_NUM
:       .byte   :+ - *, 'F', 'O', 'R' | NT_STOP, NT_VAR, '=', 1, 'T', 'O', 1
:       .byte   :+ - *, 'N', 'E', 'X', 'T' | NT_STOP, NT_VAR
:       .byte   :+ - *, 'S', 'T', 'O', 'P' | NT_STOP
:       .byte   :+ - *, 'C', 'O', 'N', 'T' | NT_STOP
:       .byte   :+ - *, 'I', 'F' | NT_STOP, 1, 'T', 'H', 'E', 'N', NT_STATEMENT
:       .byte   0

operator_name_table:
        .byte   :+ - *, '+' | NT_STOP
:       .byte   :+ - *, '-' | NT_STOP
:       .byte   :+ - *, '*' | NT_STOP
:       .byte   :+ - *, '/' | NT_STOP
:       .byte   :+ - *, '^' | NT_STOP
:       .byte   :+ - *, '&' | NT_STOP
:       .byte   :+ - *, '=' | NT_STOP
:       .byte   :+ - *, '<' | NT_STOP
:       .byte   :+ - *, '>' | NT_STOP
:       .byte   :+ - *, '<', '>' | NT_STOP
:       .byte   :+ - *, '<', '=' | NT_STOP
:       .byte   :+ - *, '>', '=' | NT_STOP
:       .byte   :+ - *, 'A', 'N', 'D' | NT_STOP
:       .byte   :+ - *, 'O', 'R' | NT_STOP
:       .byte   0

unary_operator_name_table:
        .byte   :+ - *, '-' | NT_STOP
:       .byte   :+ - *, 'N', 'O', 'T' | NT_STOP
:       .byte   0

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
