; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

; PRINT statement:

exec_print:
        jsr     evaluate_expression     ; Leaves value on stack
        jsr     pop_fp0                 ; Get the value
        jsr     print_number            ; Print the number
        jsr     newline
        clc                             ; Print always succeeds
        rts

; Prints the value in FP0 to standard output.

print_number:
        mva     #0, buffer_pos
        jsr     fp_to_string            ; Format into buffer
        ldax    #buffer
        ldy     buffer_pos
        jmp     write
