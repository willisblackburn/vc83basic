; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

.include "apple2.inc"

TOK_AT    = $15

TOK_GR    = $60
TOK_TEXT  = $61
TOK_HOME  = $62
TOK_COLOR = $63
TOK_PLOT  = $64
TOK_HLIN  = $65
TOK_VLIN  = $66

TOK_PDL   = $9A
TOK_SCRN  = $9B

.macro extension_custom_keywords
:       name_table_entry "AT"
.endmacro

.macro extension_statement_keywords
:       name_table_entry "GR"
:       name_table_entry "TEXT"
:       name_table_entry "HOME"
:       name_table_entry "COLOR"
:       name_table_entry "PLOT"
:       name_table_entry "HLIN"
:       name_table_entry "VLIN"
:       name_table_entry ""             ; Padding for even statement count
.endmacro


.macro extension_function_keywords
:       name_table_entry "PDL"
:       name_table_entry "SCRN"
.endmacro

.macro extension_pvm_statements
        BRANCH_IF_RANGE TOK_GR, 3, @done       ; GR, TEXT, HOME
        BRANCH_IF TOK_COLOR, pvm_expression
        BRANCH_IF TOK_PLOT, pvm_arg_2
        BRANCH_IF TOK_HLIN, pvm_hlin_vlin
        BRANCH_IF TOK_VLIN, pvm_hlin_vlin
.endmacro

.macro extension_pvm_functions
        BRANCH_IF TOK_PDL, pvm_fun_1
        BRANCH_IF TOK_SCRN, pvm_fun_2
.endmacro

.macro extension_statement_vectors_l
        .byte   <(SETGR-1)
        .byte   <(SETTXT-1)
        .byte   <(HOME-1)
        .byte   <(exec_color-1)
        .byte   <(exec_plot-1)
        .byte   <(exec_hlin-1)
        .byte   <(exec_vlin-1)
        .byte   0
.endmacro

.macro extension_statement_vectors_h
        .byte   >(SETGR-1)
        .byte   >(SETTXT-1)
        .byte   >(HOME-1)
        .byte   >(exec_color-1)
        .byte   >(exec_plot-1)
        .byte   >(exec_hlin-1)
        .byte   >(exec_vlin-1)
        .byte   0
.endmacro

.macro extension_statement_flags
        .byte   0                       ; GR, TEXT
        .byte   0                       ; HOME, COLOR
        .byte   0                       ; PLOT, HLIN
        .byte   0                       ; VLIN, padding
.endmacro

.macro extension_function_vectors_l
        .byte   <(fun_pdl-1)
        .byte   <(fun_scrn-1)
.endmacro

.macro extension_function_vectors_h
        .byte   >(fun_pdl-1)
        .byte   >(fun_scrn-1)
.endmacro

.macro extension_function_flags
        .byte   (PROLOG_POP_INT | EPILOG_PUSH_INT) | ((PROLOG_POP_INT | EPILOG_PUSH_INT) << 4)        ; PDL, SCRN
.endmacro

.macro extension_pvm_code
pvm_hlin_vlin:
        CALL    pvm_arg_2
        MATCH   TOK_AT
        JUMP    pvm_expression
.endmacro
