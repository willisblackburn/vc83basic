.include "basic.inc"

statement_name_table:
        .byte   :+ - *, 'R', 'U', 'N' | EOT
:       .byte   :+ - *, 'P', 'R', 'I', 'N', 'T' | EOT, 1
:       .byte   :+ - *, 'L', 'E', 'T' | EOT, NT_VAR, '=', 1
:       .byte   0
