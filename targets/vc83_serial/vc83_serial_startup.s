; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

.export startup
.import __MAIN_START__, __ONCE_LOAD__, __ONCE_SIZE__

.segment "HEADER"

        .byte   "VC83"                  ; Executable magic header
        .word   startup                 ; Start address ($0800)
        .word   __MAIN_START__          ; Segment 0 load offset ($0800)
        .byte   $00                     ; Segment 0 load segment ($00)
        .word   __ONCE_LOAD__ + __ONCE_SIZE__ - __MAIN_START__ ; Segment 0 byte size

.segment "STARTUP"

startup:
        cld                             ; Clear decimal flag
        ldx     #$FF        
        txs                             ; Initialize the stack to $FF
        jsr     initialize_target
        jsr     main        
@halt:
        jmp     @halt                   ; Nowhere to go on this platform
