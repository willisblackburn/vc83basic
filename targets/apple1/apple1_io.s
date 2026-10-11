; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

; Gets a single byte/key from keyboard (blocking).
; Returns carry clear and byte in A if ok, carry set if error.

getch:
        jsr     inkey
        bcs     getch
        rts

; Polls for a key from keyboard without blocking.
; Returns carry clear and ASCII char in A if key available, carry set if no key.

inkey:
        bit     KBDCR                   ; Bit 7 = key strobe
        bpl     @no_key
        lda     KBD
        and     #$7F
        clc
        rts
@no_key:
        sec
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

; Emits record delimiter (CR).

newline:
        lda     #$0D                    ; Carriage Return
        jmp     putch

; Emits field separator (tabs across zones).

tab:
        ldx     #4
:       lda     #' '
        jsr     putch
        dex
        bne     :-
        clc
        rts

; Reads a line of input from the Apple 1 keyboard via the 6820 PIA.
; Characters are echoed to the display as they are typed.
; Backspace (BS/$08) and Delete ($7F) erase the previous character.
; Returns when CR is entered. The line is null-terminated in buffer.
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
        cpx     #BUFFER_SIZE-1          ; Ignore if buffer is full
        bcs     @loop
        sta     buffer,x                ; Store before echoing (putch clobbers A via ora #$80)
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
        clc
        rts

; Save/load not supported on base Apple 1.

save:
load:
        sec
        rts

; Reset handler.

on_reset:
        rts

enable_console:
        clc                             ; Carry clear to display READY prompt
        rts

