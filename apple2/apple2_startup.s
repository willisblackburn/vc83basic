.include "apple2.inc"
.include "../macros.inc"
.include "../basic.inc"

.segment "STARTUP"

startup:
        cld                             ; Clear decimal flag
        ldx     #$FF        
        txs                             ; Initialize the stack to $FF
        jsr     initialize_once     
        jsr     main        
        jmp     DOSWARM                 ; Exit to resident program
        
.segment "ONCE"     
        
initialize_once:        
        lda     #$FF                    ; Print in normal mode
        sta     COUTMASK        
        jsr     CROUT                   ; Apple doesn't automatically start new line after BRUN
        rts

.code
