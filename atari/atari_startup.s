.include "atari.inc"
.include "../macros.inc"
.include "../basic.inc"

.segment "CARTHDR"

        .word   startup
        .byte   0
        .byte   4
        .word   cart_initialize  

.segment "STARTUP"

startup:
        jsr     initialize_once     
        jsr     main        
        
cart_initialize:
        rts

.segment "ONCE"     
        
initialize_once:        
        rts

.code
