; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

; POKE

exec_poke:
        jsr     evaluate_expression     ; Evaluate address and value
        inc     line_pos                ; Skip argument separator
        jsr     evaluate_expression
        jsr     pop_fp0                 ; Pop the value
        jsr     truncate_fp_to_int      ; Convert into an integer
        pha                             ; Push the low byte; high byte doesn't matter
        jsr     pop_fp0                 ; Pop the address
        jsr     truncate_fp_to_int      ; Convert into an integer
        stax    BC                      ; Park it
        ldy     #0                      ; Prepare to store
        pla                             ; Recover the value
        sta     (BC),y                  ; Store it
        rts
