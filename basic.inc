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

.struct Control
    next_line_ptr .res 2
    variable_name_ptr .res 2
    end_value .res 2
    step_value .res 2
.endstruct

.struct Float
    t .res 4
    e .res 1
.endstruct

.struct UnpackedFloat
    t .res 4
    e .res 1
    s .res 1
.endstruct

; Zero Page

.include "zeropage.inc"

BC = B
DE = D

FP0t = FP0+UnpackedFloat::t
FP0e = FP0+UnpackedFloat::e
FP0s = FP0+UnpackedFloat::s
FP1t = FP1+UnpackedFloat::t
FP1e = FP1+UnpackedFloat::e
FP1s = FP1+UnpackedFloat::s

; Core files
.include "util.s"
.include "tables.s"
.include "fp.s"
.include "name.s"
.include "parser.s"
.include "decode.s"
.include "encode.s"
.include "expression.s"
.include "program.s"
.include "control.s"
.include "input.s"
.include "let.s"
.include "list.s"
.include "print.s"
.include "run.s"

; Zero Page definitions
.include "zeropage.s"
