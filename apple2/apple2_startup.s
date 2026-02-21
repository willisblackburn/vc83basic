

.segment "STARTUP"

startup:
        cld                             ; Clear decimal flag
        ldx     #$FF        
        txs                             ; Initialize the stack to $FF
        jsr     initialize_once     
        jsr     HOME                    ; Clear screen
        jsr     _main        
        jmp     DOSWARM                 ; Exit to resident program
        
.segment "ONCE"     
        
initialize_once:        
        lda     #$FF                    ; Print in normal mode
        sta     COUTMASK        
        jsr     CROUT                   ; Apple doesn't automatically start new line after BRUN
        rts

.code
