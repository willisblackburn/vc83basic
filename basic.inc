; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

.include "macros.inc"

; Linker-defined symbols
.import __MAIN_START__, __MAIN_SIZE__
.import __BSS_RUN__, __BSS_SIZE__
.import __STACKSIZE__

.segment "CODE"

; Data structures

.struct Line
    next_line_offset .res 1
    number .res 2
    ; Following are sequences of statements consists of next_statement_offset followed by tokenized data
.endstruct

BUFFER_SIZE = 256

; Zero Page

.include "zeropage.s"

.globalzp B
.globalzp BC
.globalzp C
.globalzp D
.globalzp DE
.globalzp E

.globalzp buffer_pos
.globalzp dst_ptr
.globalzp free_ptr
.globalzp himem_ptr
.globalzp line_number
.globalzp line_ptr
.globalzp program_ptr
.globalzp size
.globalzp src_ptr

; Core files
.include "main.s"
.include "util.s"
.include "parser.s"
.include "program.s"
