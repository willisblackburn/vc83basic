; SPDX-FileCopyrightText: 2026 Willis Blackburn and Daniel Serpell
;
; SPDX-License-Identifier: MIT


readline:
        ldx     #0
        lda     #$FF
        sta     ICBLL
        stx     ICBLH
        lda     #<buffer
        sta     ICBAL
        lda     #>buffer
        sta     ICBAH
        lda     #5
        sta     ICCOM
        jsr     CIOV
        ; TODO: ignored errors
        ldx     ICBLL
        dex
        lda     #0
        sta     buffer,x
        txa
        rts

write:
        sty     ICBLL
        stx     ICBAH
        sta     ICBAL
        ldx     #0
        lda     #11
        sta     ICCOM
        jmp     CIOV

newline:
        lda     #$9B
putch:
        tay
        lda     ICPTH
        pha
        lda     ICPTL
        pha
        tya
        rts

