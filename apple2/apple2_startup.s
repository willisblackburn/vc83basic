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
        jsr     initialize_once     
        jsr     HOME                    ; Clear screen
        jsr     main        
        jmp     DOSWARM                 ; Exit to resident program
        
.segment "ONCE"     
        
initialize_once:        
        lda     #$FF                    ; Print in normal mode
        sta     COUTMASK        
        jmp     CROUT                   ; Apple doesn't automatically start new line after BRUN

.code
