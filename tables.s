.include "basic.inc"

statement_name_table:
        .byte   :+ - *, 'R', 'U', 'N' | NT_STOP
:       .byte   :+ - *, 'P', 'R', 'I', 'N', 'T' | NT_STOP, 1
:       .byte   :+ - *, 'L', 'E', 'T' | NT_STOP, NT_VAR, '=', 1
:       .byte   0
