; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

; Must export startup so the linker can find it.
.export startup

.segment "STARTUP"

startup:
        ldx     #$FF        
        txs                             ; Initialize the stack to $FF
        jsr     initialize_once     
        jsr     main        
        jmp     DOSWARM                 ; Exit to resident program

reset_handler:
        raise   PS_READY

.segment "ONCE"     
        
initialize_once:        
        cld                             ; Clear decimal flag
        lda     #$FF                    ; Print in normal mode
        sta     COUTMASK
        mvax    #reset_handler, SOFTEV  ; RESET button returns control to this program
        mva     #(>reset_handler ^ $A5), PWREDUP        
        jmp     HOME                    ; Clear screen

.code
