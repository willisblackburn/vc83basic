; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

; Must export startup so the linker can find it.
.export startup

.segment "STARTUP"

startup:
        cld                             ; Clear decimal flag
        ldx     #$FF        
        txs                             ; Initialize the stack to $FF
        jsr     initialize_target
        jsr     main        
        jmp     DOSWARM                 ; Exit to resident program


.code
