; SPDX-FileCopyrightText: 2026 Willis Blackburn and Daniel Serpell
;
; SPDX-License-Identifier: MIT

; Must export startup so the linker can find it.
.export start

;.segment "STARTUP"
.code

start:
        ldx     #$FF
        txs                             ; Initialize the stack to $FF
        jsr     initialize_target
        jsr     main
        jmp     (DOSVEC)                ; Exit to DOS

.code
