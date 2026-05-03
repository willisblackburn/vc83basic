; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

.export startup

.segment "STARTUP"

startup:
        cld                             ; Clear decimal flag
        ldx     #$FF        
        txs                             ; Initialize the stack to $FF

        ; Map $Cxxx to $30xxx
        ; The system uses ZP $02 to map $Cxxx to 20-bit addresses.
        ; $30100 is in the range mapped by $30.
        lda     #$30
        sta     $02

        jsr     initialize_target
        jsr     main        
@halt:
        jmp     @halt                   ; Nowhere to go on this platform
