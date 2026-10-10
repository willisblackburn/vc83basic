; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

; Hardware Bank Select Registers
BANK_SELECT_A   := $00

; Bus Accelerator Registers ($04-$1F)
DST_DATA            := $04
DST_DATA_INC        := $05
DST_ADDR            := $06
DST_STEP            := $09
DST_FRAC            := $0B
SRC_DATA            := $0C
SRC_DATA_INC        := $0D
SRC_ADDR            := $0E
DST_LINE_ERROR      := $0E
SRC_STEP            := $11
DST_LINE_DIAG_STEP  := $11
SRC_FRAC            := $13
DST_LINE_DIAG_FRAC  := $13
DST_MASK            := $14
COPY_SRC_DST        := $15
MODE                := $16
MUL_A               := $18
MUL_B               := $1A
MUL_C               := $1C
MUL_RESULT          := $1C
MUL_TO_DST          := $1F

MODE_1BPP           = $00
MODE_2BPP           = $01
MODE_4BPP           = $02
MODE_8BPP           = $03
MODE_LINE_BIT       = $04


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
API_READLINE    := $E02A

OPEN_READ       = 0
OPEN_WRITE      = 1
OPEN_READ_WRITE = 2
OPEN_APPEND     = 3
OPEN_DIRECTORY  = 4
OPEN_ECHO       = 8
OPEN_TERM       = 16

ERR_EOF         = $08

arg1            := $20
arg2            := $21
arg3            := $22
arg4            := $23

TOK_DIR         = $62
TOK_STATUS      = $63
TOK_GRMODE      = $64
TOK_COLOR       = $65
TOK_PLOT        = $66
TOK_DRAWTO      = $67
TOK_SETCOLOR    = $68

.macro extension_statement_keywords
:       name_table_entry "DIR"
:       name_table_entry "STATUS"
:       name_table_entry "GRMODE"
:       name_table_entry "COLOR"
:       name_table_entry "PLOT"
:       name_table_entry "DRAWTO"
:       name_table_entry "SETCOLOR"
.endmacro

.macro extension_statement_vectors_l
        .byte   <(exec_dir-1)
        .byte   <(exec_status-1)
        .byte   <(exec_grmode-1)
        .byte   <(exec_color-1)
        .byte   <(exec_plot-1)
        .byte   <(exec_drawto-1)
        .byte   <(exec_setcolor-1)
        .byte   0
.endmacro

.macro extension_statement_vectors_h
        .byte   >(exec_dir-1)
        .byte   >(exec_status-1)
        .byte   >(exec_grmode-1)
        .byte   >(exec_color-1)
        .byte   >(exec_plot-1)
        .byte   >(exec_drawto-1)
        .byte   >(exec_setcolor-1)
        .byte   0
.endmacro

.macro extension_statement_flags
        .byte   PROLOG_POP_STRING | (PROLOG_NONE << 4)  ; DIR (low nibble), STATUS (high nibble)
        .byte   PROLOG_POP_INT | (PROLOG_POP_INT << 4)  ; GRMODE (low nibble), COLOR (high nibble)
        .byte   PROLOG_POP_INT | (PROLOG_POP_INT << 4)  ; PLOT (low nibble), DRAWTO (high nibble)
        .byte   PROLOG_POP_INT | (0 << 4)               ; SETCOLOR (low nibble), padding (high nibble)
.endmacro

.macro extension_pvm_statements
        BRANCH_IF TOK_DIR, pvm_expression
        BRANCH_IF TOK_STATUS, pvm_get
        BRANCH_IF TOK_GRMODE, pvm_expression
        BRANCH_IF TOK_COLOR, pvm_expression
        BRANCH_IF TOK_PLOT, pvm_arg_2
        BRANCH_IF TOK_DRAWTO, pvm_arg_2
        BRANCH_IF TOK_SETCOLOR, pvm_setcolor
.endmacro

.macro extension_pvm_code
pvm_setcolor:
        CALL    pvm_expression
        MATCH   TOK_COMMA
        CALL    pvm_expression
        MATCH   TOK_COMMA
        CALL    pvm_expression
        MATCH   TOK_COMMA
        CALL    pvm_expression
        MATCH   TOK_COMMA
        JUMP    pvm_expression
.endmacro


