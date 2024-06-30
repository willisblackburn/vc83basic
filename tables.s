.include "basic.inc"

statement_name_table:
        .byte   run_end - *, 'R', 'U', 'N' | NT_STOP
run_end:
        .byte   print_end - *, 'P', 'R', 'I', 'N', 'T' | NT_STOP, 1
print_end:
        .byte   let_end - *, 'L', 'E', 'T' | NT_STOP, NT_VAR, '=', 1
let_end:
        .byte   input_end - *, 'I', 'N', 'P', 'U', 'T' | NT_STOP, NT_RPT_VAR
input_end:
        .byte   list_end - *, 'L', 'I', 'S', 'T' | NT_STOP, 2
list_end:
        .byte   0
