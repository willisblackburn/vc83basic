; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT


.code

newline:
        lda     #$0D                    ; Carriage Return
        jsr     putch
        lda     #$0A                    ; Line Feed
        jmp     putch

write:
        stax    BC
        tya
        tax
        beq     @done
        ldy     #0
@next:
        lda     (BC),y
        jsr     putch
        iny
        dex
        bne     @next
@done:
        rts

putch:
        pha
@wait:
        lda     UART_TX_LEVEL
        cmp     #8
        bcs     @wait                   ; Wait if FIFO full
        pla
        sta     UART_TX_DATA
        rts

readline:
        ldx     #0
@loop:
@wait_rx:
        lda     UART_RX_LEVEL
        beq     @wait_rx
        
        lda     UART_RX_DATA
        
        cmp     #$0D                    ; Carriage Return?
        beq     @cr
        cmp     #$08                    ; Backspace (Ctrl-H)?
        beq     @bs
        cmp     #$7F                    ; Delete?
        beq     @bs
        
        ; Standard character
        sta     buffer,x
        jsr     putch                   ; Echo
        inx
        cpx     #MAX_LINE_LENGTH
        bcc     @loop
        ; If line full, just loop until CR/BS
        dex
        jmp     @loop

@bs:
        cpx     #0
        beq     @loop                   ; At start of line, ignore
        dex
        lda     #$08                    ; BS
        jsr     putch
        lda     #' '                    ; Overwrite with space
        jsr     putch
        lda     #$08                    ; Move back again
        jsr     putch
        jmp     @loop

@cr:
        lda     #0
        sta     buffer,x                ; Nul-terminate
        txa                             ; Return length
        pha
        jsr     newline                 ; Echo newline
        pla
        rts
