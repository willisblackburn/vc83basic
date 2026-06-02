; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

; cc65 runtime
.importzp c_sp

; sim65 vectors
.import exit

; Must export startup so the linker can find it.
.export startup

.segment "STARTUP"

startup:
        cld                             ; Clear decimal flag
        ldx     #$FF
        txs                             ; Initialize the stack to $FF
        mvax    #(__MAIN_START__ + __MAIN_SIZE__ + __STACKSIZE__), c_sp
        jsr     initialize_target
        jsr     main        
        jmp     exit                    ; Return 0 from sim65

.code
