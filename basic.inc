; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

.include "macros.inc"

; Linker-defined symbols
.import __MAIN_START__, __MAIN_SIZE__
.import __BSS_RUN__, __BSS_SIZE__
.import __STACKSIZE__

.segment "CODE"

.include "constants.inc"

; Data structures

.struct Line
    next_line_offset .res 1
    number .res 2
    ; Following are sequences of statements consists of next_statement_offset followed by tokenized data
.endstruct

; Zero Page

.include "zeropage.s"

BC = B
DE = D

; Core files
.include "util.s"
.include "tables.s"
.include "name.s"
.include "parser.s"
.include "decode.s"
.include "encode.s"
.include "expression.s"
.include "program.s"
.include "let.s"
.include "main.s"
.include "print.s"
.include "run.s"
