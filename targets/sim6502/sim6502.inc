; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

O_RDONLY  = $01
O_WRONLY  = $02
O_RDWR    = $03
O_CREAT   = $10
O_TRUNC   = $20
O_APPEND  = $40
O_EXCL    = $80

TOK_OPEN  = $60
TOK_CLOSE = $61
TOK_BYE   = $62
TOK_VER_S = $9A

.macro extension_statement_keywords
:       name_table_entry "OPEN"
:       name_table_entry "CLOSE"
:       name_table_entry "BYE"
:       name_table_entry ""             ; Padding for even statement count
.endmacro

.macro extension_function_keywords
:       name_table_entry "VER$"
:       name_table_entry ""             ; Padding for even function count
.endmacro

.macro extension_pvm_statements
        BRANCH_IF TOK_OPEN, pvm_open
        BRANCH_IF TOK_CLOSE, pvm_close
        BRANCH_IF TOK_BYE, @done
.endmacro

.macro extension_pvm_code
pvm_open:
        CALL    pvm_channel
        CALL    pvm_expression
        BRANCH_IF TOK_COMMA, pvm_expression
        RETURN

pvm_close:
        CALL    pvm_channel
        RETURN
.endmacro

.macro extension_pvm_functions
        BRANCH_IF TOK_VER_S, pvm_fun_0
.endmacro

.macro extension_statement_vectors_l
        .byte   <(exec_open-1)
        .byte   <(exec_close-1)
        .byte   <(exec_bye-1)
        .byte   0
.endmacro

.macro extension_statement_vectors_h
        .byte   >(exec_open-1)
        .byte   >(exec_close-1)
        .byte   >(exec_bye-1)
        .byte   0
.endmacro

.macro extension_statement_flags
        .byte   0                       ; OPEN + CLOSE
        .byte   0                       ; BYE + padding
.endmacro

.macro extension_function_vectors_l
        .byte   <(fun_ver_s-1)
        .byte   0
.endmacro

.macro extension_function_vectors_h
        .byte   >(fun_ver_s-1)
        .byte   0
.endmacro

.macro extension_function_flags
        .byte   (PROLOG_NONE | EPILOG_PUSH_STRING) | (0 << 4)                                   ; VER$ + padding
.endmacro
