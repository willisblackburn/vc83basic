; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

; Must export startup so the linker can find it.
.export start

;.segment "STARTUP"
.code

start:
        ldx     #$FF
        txs                             ; Initialize the stack to $FF
        jsr     initialize_once
        jsr     main
        jmp     (DOSVEC)                ; Exit to DOS

;.segment "ONCE"
;
initialize_once:
initialize_target:
        rts

.code
