; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

.code

; Outputs a carriage return (moves to next line on the Apple 1 display).

newline:
        lda     #$0D                    ; Carriage Return
        jmp     putch

; Writes bytes to the display.
; AX = pointer to buffer, Y = length

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

; Writes a single character to the Apple 1 display via the 6820 PIA.
; Waits until the previous character has been consumed (bit 7 of DSP clear),
; then writes the character with bit 7 set as required by the PIA.

putch:
@wait:
        bit     DSP                     ; Test bit 7: set = display busy
        bmi     @wait                   ; Wait while busy
        ora     #$80                    ; Set bit 7 (required by Apple 1 PIA)
        sta     DSP
        rts

; Reads a line of input from the Apple 1 keyboard via the 6820 PIA.
; Characters are echoed to the display as they are typed.
; Backspace (BS/$08) and Delete ($7F) erase the previous character.
; Returns when CR is entered.  The line is null-terminated in buffer.
; Returns the line length in A.

readline:
        ldx     #0
@loop:
@wait_rx:
        bit     KBDCR                   ; Test bit 7: set = new key available
        bpl     @wait_rx                ; Wait while no key
        lda     KBD                     ; Read character (keyboard sets bit 7)
        and     #$7F                    ; Strip bit 7 to get 7-bit ASCII
        cmp     #$0D                    ; Carriage return — end of line?
        beq     @cr
        cmp     #$08                    ; Backspace?
        beq     @bs
        cmp     #$7F                    ; Delete?
        beq     @bs
        cmp     #$20                    ; Ignore non-printable characters below space
        bcc     @loop
        cpx     #MAX_LINE_LENGTH        ; Ignore if buffer is full
        bcs     @loop
        sta     buffer,x               ; Store before echoing (putch clobbers A via ora #$80)
        jsr     putch                   ; Echo the character
        inx
        jmp     @loop

@bs:
        cpx     #0
        beq     @loop                   ; Nothing to delete at start of line
        dex
        lda     #$08                    ; BS — move cursor left
        jsr     putch
        lda     #' '                    ; Overwrite previous character with space
        jsr     putch
        lda     #$08                    ; Move cursor left again
        jsr     putch
        jmp     @loop

@cr:
        jsr     putch                   ; Echo CR to advance to next line
        lda     #0
        sta     buffer,x                ; Null-terminate the line
        txa                             ; Return length in A
        rts
