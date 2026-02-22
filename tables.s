; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

function_arity_table:
        .byte   1   ; LEN
        .byte   1   ; STR$
        .byte   1   ; CHR$
        .byte   1   ; ASC
        .byte   2   ; LEFT$
        .byte   2   ; RIGHT$
        .byte   3   ; MID$
        .byte   1   ; VAL
        .byte   0   ; FRE
        .byte   1   ; PEEK
        .byte   1   ; ADR
        .byte   2   ; USR
        .byte   1   ; INT
        .byte   1   ; ROUND
        .byte   1   ; LOG
        .byte   1   ; EXP
        .byte   1   ; SIN
        .byte   1   ; COS
        .byte   1   ; TAN
        .byte   1   ; ATN
        .byte   1   ; ABS
        .byte   1   ; SGN
        .byte   1   ; SQR

; Operator precedence table
; We index this by the operator index divided by 2.

operator_precedence_table:
        .byte   PR_ADD                  ; +, -
        .byte   PR_MUL                  ; *, /
        .byte   PR_POW                  ; ^, &
        .byte   PR_RELATIONAL           ; =, <>
        .byte   PR_RELATIONAL           ; <=, <
        .byte   PR_RELATIONAL           ; >=, >
        .byte   PR_LOGICAL              ; AND, OR

type_size_table:
        .byte .sizeof(Float)            ; TYPE_NUMBER
        .byte 2                         ; TYPE_STRING

error_message_table:
        .byte :+ - *, "STOPPED"
:       .byte :+ - *, "SYS ERR"
:       .byte :+ - *, "OUT MEM"
:       .byte :+ - *, "TYPE?"
:       .byte :+ - *, "NO STOP"
:       .byte :+ - *, "OUT DATA"
:       .byte :+ - *, "O'FLOW"
:       .byte :+ - *, "U'FLOW"
:       .byte :+ - *, "NO GOSUB"
:       .byte :+ - *, "NO FOR"
:       .byte :+ - *, "LINE?"
:       .byte :+ - *, "RANGE"
:       .byte :+ - *, "BAD VAR"
:       .byte :+ - *, "EXISTS"
:       .byte :+ - *, "TOO LONG"
:       .byte :+ - *, "COMPLEX"
:       .byte :+ - *, "FORMAT"
:       .byte :+ - *, "ARITY?"
:       .byte :+ - *, "SYN ERR"
:       .byte :+ - *, "NO RUN"
:       .byte :+ - *, "DIV/0"
:       .byte 0