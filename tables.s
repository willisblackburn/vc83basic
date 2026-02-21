
statement_name_table:
        .byte   :+ - *, 'R', 'U', 'N' | EOT
:       .byte   :+ - *, 'P', 'R', 'I', 'N', 'T' | EOT, 1
:       .byte   :+ - *, 'L', 'E', 'T' | EOT, NT_VAR, '=', 1
:       .byte   :+ - *, 'I', 'N', 'P', 'U', 'T' | EOT, NT_RPT_VAR
:       .byte   :+ - *, 'L', 'I', 'S', 'T' | EOT
:       .byte   0

operator_name_table:
        .byte   :+ - *, '+' | EOT
:       .byte   :+ - *, '-' | EOT
:       .byte   :+ - *, '*' | EOT
:       .byte   :+ - *, '/' | EOT
:       .byte   :+ - *, '^' | EOT
:       .byte   0

unary_operator_name_table:
        .byte   :+ - *, '-' | EOT
:       .byte   0
