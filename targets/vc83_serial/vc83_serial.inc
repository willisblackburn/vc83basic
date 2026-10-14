; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

; Hardware Bank Select Registers
BANK_SELECT_A   := $00
BANK_SELECT_D   := $03

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

MODE_8BPP           = $00
MODE_4BPP           = $01
MODE_2BPP           = $02
MODE_1BPP           = $03
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
OPEN_RAW        = 16
OPEN_ACCESS_MASK = $03

ERR_EOF         = $08

arg1            := $20
arg2            := $21
arg3            := $22
arg4            := $23
path_ptr        := $31
path_len        := $33
io_ptr          := $34
io_seg          := $36
io_len          := $37

TOK_OPEN        = $60
TOK_CLOSE       = $61
TOK_XIO         = $62
TOK_DIR         = $63
TOK_STATUS      = $64
TOK_GRMODE      = $65
TOK_COLOR       = $66
TOK_PLOT        = $67
TOK_DRAWTO      = $68
TOK_SETCOLOR    = $69
TOK_SOURCE      = $6A
TOK_SYNC        = $6B
TOK_POKE24      = $6C
TOK_DPOKE24     = $6D

TOK_COLORAT     = $9A
TOK_PEEK24      = $9C
TOK_DPEEK24     = $9D

.macro extension_statement_keywords
:       name_table_entry "OPEN"
:       name_table_entry "CLOSE"
:       name_table_entry "XIO"
:       name_table_entry "DIR"
:       name_table_entry "STATUS"
:       name_table_entry "GRMODE"
:       name_table_entry "COLOR"
:       name_table_entry "PLOT"
:       name_table_entry "DRAWTO"
:       name_table_entry "SETCOLOR"
:       name_table_entry "SOURCE"
:       name_table_entry "SYNC"
:       name_table_entry "POKE24"
:       name_table_entry "DPOKE24"
.endmacro

.macro extension_statement_vectors_l
        .byte   <(exec_open-1)
        .byte   <(exec_close-1)
        .byte   <(exec_xio-1)
        .byte   <(exec_dir-1)
        .byte   <(exec_status-1)
        .byte   <(exec_grmode-1)
        .byte   <(exec_color-1)
        .byte   <(exec_plot-1)
        .byte   <(exec_drawto-1)
        .byte   <(exec_setcolor-1)
        .byte   <(exec_source-1)
        .byte   <(exec_sync-1)
        .byte   <(exec_poke24-1)
        .byte   <(exec_dpoke24-1)
.endmacro

.macro extension_statement_vectors_h
        .byte   >(exec_open-1)
        .byte   >(exec_close-1)
        .byte   >(exec_xio-1)
        .byte   >(exec_dir-1)
        .byte   >(exec_status-1)
        .byte   >(exec_grmode-1)
        .byte   >(exec_color-1)
        .byte   >(exec_plot-1)
        .byte   >(exec_drawto-1)
        .byte   >(exec_setcolor-1)
        .byte   >(exec_source-1)
        .byte   >(exec_sync-1)
        .byte   >(exec_poke24-1)
        .byte   >(exec_dpoke24-1)
.endmacro

.macro extension_statement_flags
        .byte   0                                       ; OPEN, CLOSE
        .byte   PROLOG_NONE | (PROLOG_POP_STRING << 4)  ; XIO, DIR
        .byte   PROLOG_NONE | (PROLOG_POP_INT << 4)     ; STATUS, GRMODE
        .byte   PROLOG_POP_INT | (PROLOG_POP_INT << 4)  ; COLOR, PLOT
        .byte   PROLOG_POP_INT | (PROLOG_POP_INT << 4)  ; DRAWTO, SETCOLOR
        .byte   PROLOG_POP_STRING | (PROLOG_POP_INT << 4) ; SOURCE, SYNC
        .byte   PROLOG_POP_INT | (PROLOG_POP_INT << 4)  ; POKE24, DPOKE24
.endmacro

.macro extension_pvm_statements
        BRANCH_IF TOK_OPEN, pvm_open
        BRANCH_IF TOK_CLOSE, pvm_close
        BRANCH_IF TOK_XIO, pvm_xio
        BRANCH_IF TOK_DIR, pvm_expression
        BRANCH_IF TOK_STATUS, pvm_get
        BRANCH_IF TOK_GRMODE, pvm_expression
        BRANCH_IF TOK_COLOR, pvm_expression
        BRANCH_IF TOK_PLOT, pvm_arg_2
        BRANCH_IF TOK_DRAWTO, pvm_arg_2
        BRANCH_IF TOK_SETCOLOR, pvm_setcolor
        BRANCH_IF TOK_SOURCE, pvm_expression
        BRANCH_IF TOK_SYNC, pvm_expression
        BRANCH_IF_RANGE TOK_POKE24, 2, pvm_arg_2
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

pvm_xio:
        CALL    pvm_channel
        CALL    pvm_expression
        BRANCH_IF TOK_COMMA, @arg1
        RETURN
@arg1:
        CALL    pvm_expression
        BRANCH_IF TOK_COMMA, pvm_expression
        RETURN

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

.macro extension_function_keywords
:       name_table_entry "COLORAT"
:       name_table_entry ""             ; Padding for even function count
:       name_table_entry "PEEK24"
:       name_table_entry "DPEEK24"
.endmacro

.macro extension_pvm_functions
        BRANCH_IF TOK_COLORAT, pvm_fun_2
        BRANCH_IF_RANGE TOK_PEEK24, 2, pvm_fun_1
.endmacro

.macro extension_function_vectors_l
        .byte   <(fun_colorat-1)
        .byte   0
        .byte   <(fun_peek24-1)
        .byte   <(fun_dpeek24-1)
.endmacro

.macro extension_function_vectors_h
        .byte   >(fun_colorat-1)
        .byte   0
        .byte   >(fun_peek24-1)
        .byte   >(fun_dpeek24-1)
.endmacro

.macro extension_function_flags
        .byte   (PROLOG_POP_INT | EPILOG_PUSH_INT) | (0 << 4)                                   ; COLORAT + padding
        .byte   (PROLOG_POP_FP | EPILOG_PUSH_INT) | ((PROLOG_POP_FP | EPILOG_PUSH_INT) << 4) ; PEEK24, DPEEK24
.endmacro



