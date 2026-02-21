; cc65 runtime
.importzp c_sp

; sim65 vectors
.import exit



.segment "STARTUP"

startup:
        cld                             ; Clear decimal flag
        ldx     #$FF
        txs                             ; Initialize the stack to $FF
        mvax    #(__MAIN_START__ + __MAIN_SIZE__ + __STACKSIZE__), c_sp
        jsr     _main        
        jmp     exit                    ; Return 0 from sim65

.code
