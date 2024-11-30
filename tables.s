.include "basic.inc"

statement_name_table:
        .byte   :+ - *, 'R', 'U', 'N' | NT_STOP
:       .byte   :+ - *, 'P', 'R', 'I', 'N', 'T' | NT_STOP, 1
:       .byte   :+ - *, 'L', 'E', 'T' | NT_STOP, NT_VAR, '=', 1
:       .byte   :+ - *, 'I', 'N', 'P', 'U', 'T' | NT_STOP, NT_RPT_VAR
:       .byte   :+ - *, 'L', 'I', 'S', 'T' | NT_STOP, 2
:       .byte   0

operator_name_table:
        .byte   :+ - *, '+' | NT_STOP
:       .byte   :+ - *, '-' | NT_STOP
:       .byte   :+ - *, '*' | NT_STOP
:       .byte   :+ - *, '/' | NT_STOP
:       .byte   :+ - *, '^' | NT_STOP
:       .byte   0

unary_operator_name_table:
        .byte   :+ - *, '-' | NT_STOP
:       .byte   0

; Operator precedence table
; We index this by the operator index divided by 2.

operator_precedence_table:
        .byte   PR_ADD                  ; +, -
        .byte   PR_MUL                  ; *, /
        .byte   PR_POW                  ; ^
