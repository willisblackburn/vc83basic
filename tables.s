
statement_name_table:
        .byte   :+ - *, 'E', 'N', 'D' | EOT
:       .byte   :+ - *, 'R', 'U', 'N' | EOT
:       .byte   :+ - *, 'P', 'R', 'I', 'N', 'T' | EOT, NT_PRINT_EXP
:       .byte   :+ - *, 'L', 'E', 'T' | EOT, NT_VAR, '=', 1
:       .byte   :+ - *, 'I', 'N', 'P', 'U', 'T' | EOT, NT_RPT_VAR
:       .byte   :+ - *, 'L', 'I', 'S', 'T' | EOT
:       .byte   :+ - *, 'G', 'O', 'T', 'O' | EOT, NT_NUMBER
:       .byte   :+ - *, 'G', 'O', 'S', 'U', 'B' | EOT, NT_NUMBER
:       .byte   :+ - *, 'R', 'E', 'T', 'U', 'R', 'N' | EOT
:       .byte   :+ - *, 'P', 'O', 'P' | EOT
:       .byte   :+ - *, 'O', 'N' | EOT, 1, 'G', 'O', 'T', 'O', NT_RPT_NUMBER
:       .byte   :+ - *, 'O', 'N' | EOT, 1, 'G', 'O', 'S', 'U', 'B', NT_RPT_NUMBER
:       .byte   :+ - *, 'F', 'O', 'R' | EOT, NT_VAR, '=', 1, 'T', 'O', 1
:       .byte   :+ - *, 'N', 'E', 'X', 'T' | EOT, NT_VAR
:       .byte   :+ - *, 'S', 'T', 'O', 'P' | EOT
:       .byte   :+ - *, 'C', 'O', 'N', 'T' | EOT
:       .byte   :+ - *, 'I', 'F' | EOT, 1, 'T', 'H', 'E', 'N', NT_STATEMENT
:       .byte   :+ - *, 'N', 'E', 'W' | EOT
:       .byte   :+ - *, 'C', 'L', 'R' | EOT
:       .byte   0

operator_name_table:
        .byte   :+ - *, '+' | EOT
:       .byte   :+ - *, '-' | EOT
:       .byte   :+ - *, '*' | EOT
:       .byte   :+ - *, '/' | EOT
:       .byte   :+ - *, '^' | EOT
:       .byte   :+ - *, '&' | EOT
:       .byte   :+ - *, '=' | EOT
:       .byte   :+ - *, '<' | EOT
:       .byte   :+ - *, '>' | EOT
:       .byte   :+ - *, '<', '>' | EOT
:       .byte   :+ - *, '<', '=' | EOT
:       .byte   :+ - *, '>', '=' | EOT
:       .byte   :+ - *, 'A', 'N', 'D' | EOT
:       .byte   :+ - *, 'O', 'R' | EOT
:       .byte   0

unary_operator_name_table:
        .byte   :+ - *, '-' | EOT
:       .byte   :+ - *, 'N', 'O', 'T' | EOT
:       .byte   0

; Operator precedence table
; We index this by the operator index divided by 2.

operator_precedence_table:
        .byte   PR_ADD                  ; +, -
        .byte   PR_MUL                  ; *, /
        .byte   PR_POW                  ; ^, &
        .byte   PR_RELATIONAL           ; =, <>
        .byte   PR_RELATIONAL           ; <=, <
        .byte   PR_RELATIONAL           ; >=, >
        .byte   PR_LOGICAL              ; AND, OR
