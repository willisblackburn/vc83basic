; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

; POKE

exec_poke:
        stax    DE                      ; Save
        jsr     pop_int_fp0             ; Pop the address
        stax    BC                      ; Park it
        ldy     #0                      ; Prepare to store
        lda     D
        sta     (BC),y                  ; Store it
        rts


exec_pokew:
        jsr     exec_poke               ; Leaves high byte in E and Y=0
        iny
        lda     E
        sta     (BC),y                  ; Store it
        rts

