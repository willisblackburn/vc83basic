; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

.segment "PARSER"

ex_statement_name_table:
        name_table_entry "GR"
:       name_table_entry "TEXT"
:       name_table_entry "HOME"
:       name_table_entry "COLOR"
            JUMP pvm_expression
:       name_table_entry "PLOT"
            JUMP pvm_arg_2
:       name_table_entry "HLIN"
            CALL pvm_arg_2
            MATCH "AT"
            JUMP pvm_expression
:       name_table_entry "VLIN"
            CALL pvm_arg_2
            MATCH "AT"
            JUMP pvm_expression
:       name_table_end

ex_function_name_table:
        name_table_entry "PDL"
:       name_table_entry "SCRN"
:       name_table_end

.segment "XVEC"

ex_statement_vectors:
        .word   SETGR-1
        .word   SETTXT-1
        .word   HOME-1
        .word   exec_color-1
        .word   exec_plot-1
        .word   exec_hlin-1
        .word   exec_vlin-1
        
.code

exec_color:
        jsr     evaluate_expression
        jsr     pop_int_fp0             ; Pop the color value
        jmp     SETCOL

exec_plot:
        jsr     evaluate_argument_list
        jsr     pop_int_fp0             ; Pop the Y value
        pha                             ; We'll move it into A later
        jsr     pop_int_fp0             ; Pop the X value
        tay                             ; Move X into Y for PLOT
        pla                             ; Get back Y from stack into A
        jmp     PLOT

exec_hlin:
        jsr     get_hlin_vlin_arguments
        jmp     HLINE

exec_vlin:
        jsr     get_hlin_vlin_arguments
        jmp     VLINE

get_hlin_vlin_arguments:
        jsr     evaluate_argument_list  ; Evaluate start and end
        inc     line_pos                ; Skip "AT"
        inc     line_pos
        jsr     evaluate_expression
        jsr     pop_int_fp0             ; Get coordinate (Row for HLIN, Column for VLIN)
        pha                             ; Save on hardware stack
        jsr     pop_int_fp0             ; Get end point (H2/V2)
        sta     H2
        sta     V2
        jsr     pop_int_fp0             ; Get start point
        tay                             ; Start point into Y
        pla                             ; Coordinate into A
        rts

.segment "XFUNC"

ex_function_table:
        .word   fun_pdl-1
        .byte   1 | PROLOG_POP_INT | EPILOG_PUSH_INT
        .word   fun_scrn-1
        .byte   2 | PROLOG_POP_INT | EPILOG_PUSH_INT

.code

fun_pdl:
        jsr     pop_int_fp0             ; Get paddle index
        tax
        jsr     PREAD                   ; Returns result in Y
        tya
        ldx     #0
        rts

fun_scrn:
        jsr     pop_int_fp0             ; Pop the Y value (second arg)
        pha                             ; Save it
        jsr     pop_int_fp0             ; Pop the X value (first arg)
        tay                             ; Move X into Y
        pla                             ; Get back Y into A
        jsr     SCRN
        ldx     #0                      ; Make sure high byte is 0
        rts
