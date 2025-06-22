.include "basic.inc"

statement_name_table:
        .byte   :+ - *, 'E', 'N', 'D' | EOT
:       .byte   :+ - *, 'R', 'U', 'N' | EOT
:       .byte   :+ - *, 'P', 'R', 'I', 'N', 'T' | EOT, NT_PRINT_EXP
:       .byte   :+ - *, 'L', 'E', 'T' | EOT, NT_VAR, '=' | EOT, 1
:       .byte   :+ - *, 'I', 'N', 'P', 'U', 'T' | EOT, NT_RPT_VAR
:       .byte   :+ - *, 'L', 'I', 'S', 'T' | EOT, 2
:       .byte   :+ - *, 'G', 'O', 'T', 'O' | EOT, NT_NUMBER
:       .byte   :+ - *, 'G', 'O', 'S', 'U', 'B' | EOT, NT_NUMBER
:       .byte   :+ - *, 'R', 'E', 'T', 'U', 'R', 'N' | EOT
:       .byte   :+ - *, 'P', 'O', 'P' | EOT
:       .byte   :+ - *, 'O', 'N' | EOT, 1, 'G', 'O', 'T', 'O' | EOT, NT_RPT_NUMBER
:       .byte   :+ - *, 'O', 'N' | EOT, 1, 'G', 'O', 'S', 'U', 'B' | EOT, NT_RPT_NUMBER
:       .byte   :+ - *, 'F', 'O', 'R' | EOT, NT_VAR, '=' | EOT, 1, 'T', 'O' | EOT, 1
:       .byte   :+ - *, 'N', 'E', 'X', 'T' | EOT, NT_VAR
:       .byte   :+ - *, 'S', 'T', 'O', 'P' | EOT
:       .byte   :+ - *, 'C', 'O', 'N', 'T' | EOT
:       .byte   :+ - *, 'I', 'F' | EOT, 1, 'T', 'H', 'E', 'N' | EOT, NT_STATEMENT
:       .byte   :+ - *, 'N', 'E', 'W' | EOT
:       .byte   :+ - *, 'C', 'L', 'R' | EOT
:       .byte   :+ - *, 'D', 'I', 'M' | EOT, NT_VAR
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

function_name_table:
        .byte   :+ - *, 'L', 'E', 'N' | EOT
:       .byte   :+ - *, 'S', 'T', 'R', '$' | EOT
:       .byte   :+ - *, 'C', 'H', 'R', '$' | EOT
:       .byte   :+ - *, 'A', 'S', 'C' | EOT
:       .byte   :+ - *, 'L', 'E', 'F', 'T', '$' | EOT
:       .byte   :+ - *, 'R', 'I', 'G', 'H', 'T', '$' | EOT
:       .byte   :+ - *, 'M', 'I', 'D', '$' | EOT
:       .byte   :+ - *, 'V', 'A', 'L' | EOT
:       .byte   :+ - *, 'F', 'R', 'E' | EOT
:       .byte   0

function_arity_table:
        .byte   1   ; LEN
        .byte   1   ; STR$
        .byte   1   ; CHR$
        .byte   1   ; ASC
        .byte   2   ; LEFT$
        .byte   2   ; RIGHT$
        .byte   3   ; MID$
        .byte   1   ; VAL
        .byte   0   ; FRE

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

type_size_table:
        .byte .sizeof(Float)            ; TYPE_NUMBER
        .byte 2                         ; TYPE_STRING
