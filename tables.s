; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

type_size_table:
        .byte .sizeof(Float)            ; TYPE_NUMBER
        .byte 2                         ; TYPE_STRING

error_message_table:
        .byte :+ - *, "STOPPED"
:       .byte :+ - *, "?!"
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
:       .byte :+ - *, "SYNTAX"
:       .byte :+ - *, "NOT RUN"
:       .byte :+ - *, "DIV/0"
:       .byte 0