; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

; Hardware Bank Select Registers
BANK_SELECT_A   := $00

; OS API Vectors and Registers
API_VCGALAYER   := $E003
API_OPEN        := $E006
API_CLOSE       := $E009
API_GET         := $E00C
API_PUT         := $E00F
API_READ        := $E012
API_WRITE       := $E015
API_STATUS      := $E018
API_XIO         := $E01B

OPEN_READ       = 0
OPEN_WRITE      = 1
OPEN_DIRECTORY  = 4

ERR_EOF         = $08

arg1            := $20
arg2            := $21
arg3            := $22
arg4            := $23

TOK_DIR         = $62
TOK_STATUS      = $63
TOK_GRMODE      = $64

.macro extension_statement_keywords
:       name_table_entry "DIR"
:       name_table_entry "STATUS"
:       name_table_entry "GRMODE"
.endmacro

.macro extension_statement_vectors_l
        .byte   <(exec_dir-1)
        .byte   <(exec_status-1)
        .byte   <(exec_grmode-1)
.endmacro

.macro extension_statement_vectors_h
        .byte   >(exec_dir-1)
        .byte   >(exec_status-1)
        .byte   >(exec_grmode-1)
.endmacro

.macro extension_statement_flags
        .byte   PROLOG_POP_STRING | (PROLOG_NONE << 4)  ; DIR (low nibble), STATUS (high nibble)
        .byte   PROLOG_POP_INT | (0 << 4)               ; GRMODE (low nibble), padding (high nibble)
.endmacro

.macro extension_pvm_statements
        BRANCH_IF TOK_DIR, pvm_expression
        BRANCH_IF TOK_STATUS, pvm_get
        BRANCH_IF TOK_GRMODE, pvm_expression
.endmacro

