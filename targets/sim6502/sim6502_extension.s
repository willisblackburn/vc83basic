; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

; exit function provided by sim6502
.import exit

.segment "PARSER"

ex_statement_name_table:
        name_table_entry "BYE"
:       name_table_end

ex_function_name_table:
        name_table_entry "VER$"
:       name_table_end

.segment "XVEC"

ex_statement_vectors:
        .word   exec_bye-1

.code

; BYE: exits the interpeter

exec_bye:
        jmp     exit

.segment "XFUNC"

ex_function_table:
        .word   fun_ver_s-1
        .byte   1 | PROLOG_POP_FP | EPILOG_PUSH_STRING

.code

version:
.include "version.inc"
version_length = * - version

fun_ver_s:
        lda     #version_length         ; Ignore argument
        jsr     string_alloc_for_copy
        ldax    #version
        jmp     copy_y_from
