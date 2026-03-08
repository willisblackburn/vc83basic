; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

; exit function provided by sim6502
.import exit

.segment "PARSER"

ex_statement_name_table:
        name_table_entry "BYE"
            RETURN
:       name_table_end

ex_function_name_table:
        name_table_entry "VER$"
:       name_table_end

.code

ex_statement_vectors:
        .word   exec_bye-1

; BYE: exits the interpeter

exec_bye:
        jmp     exit

ex_function_arity_table:
        .byte   1                       ; VER

ex_function_vectors:
        .word   fun_ver-1

version:
.include "version.inc"
version_length = * - version

fun_ver:
        jsr     pop_fp0                 ; Ignore argument
        lda     #version_length
        jsr     string_alloc
        sta     dst_ptr                 ; New string is destination for the copy
        inc     dst_ptr                 ; Move past length byte
        bne     @skip_iny
        iny
@skip_iny:
        sty     dst_ptr+1
        ldax    #version
        ldy     #version_length
        jsr     copy_y_from
        jmp     push_string
