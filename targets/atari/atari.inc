; SPDX-FileCopyrightText: 2026 Willis Blackburn and Daniel Serpell
;
; SPDX-License-Identifier: MIT

DOSINI = $0C
DOSVEC = $0A
BRKKEY = $11
COLCRS = $55

CH     = $02FC
HATABS = $031A

ICCOM  = $0342
ICSTA  = $0343
ICBAL  = $0344
ICBAH  = $0345
ICPTL  = $0346
ICPTH  = $0347
ICBLL  = $0348
ICBLH  = $0349
ICAX1  = $034A
ICAX2  = $034B

CIOV   = $E456

TOK_OPEN  = $60
TOK_CLOSE = $61
TOK_XIO   = $62
TOK_DOS   = $63

.macro extension_statement_keywords
:       name_table_entry "OPEN"
:       name_table_entry "CLOSE"
:       name_table_entry "XIO"
:       name_table_entry "DOS"
.endmacro

.macro extension_pvm_statements
        BRANCH_IF TOK_OPEN, pvm_open
        BRANCH_IF TOK_CLOSE, pvm_close
        BRANCH_IF TOK_XIO, pvm_xio
        BRANCH_IF TOK_DOS, @done
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
.endmacro

.macro extension_statement_vectors_l
        .byte   <(exec_open-1)
        .byte   <(exec_close-1)
        .byte   <(exec_xio-1)
        .byte   <(exec_dos-1)
.endmacro

.macro extension_statement_vectors_h
        .byte   >(exec_open-1)
        .byte   >(exec_close-1)
        .byte   >(exec_xio-1)
        .byte   >(exec_dos-1)
.endmacro

.macro extension_statement_flags
        .byte   0                       ; OPEN + CLOSE
        .byte   0                       ; XIO + DOS
.endmacro

