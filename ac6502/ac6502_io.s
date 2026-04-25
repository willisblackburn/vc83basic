; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn / 2026 A.C. Wright
;
; SPDX-License-Identifier: MIT

readline:
        ldy     #0
@waitchar:
        jsr     CHRIN
        bcc     @waitchar
        ; Check for break keys (ESC or CTRL-C) to interrupt a running program
        cmp     #CH_ESC
        beq     @check_break
        cmp     #CH_CTRLC
        beq     @check_break
        ; Check for backspace
        cmp     #CH_BKSP
        beq     @backspace
        ; Check for CR (end of line)
        cmp     #CH_CR
        beq     @done
        ; Skip other non-printable control characters (LF, NUL, etc.)
        cmp     #CH_SPACE
        bcc     @waitchar
        ; Skip DEL ($7F)
        cmp     #$7F
        beq     @waitchar
        ; Ignore if buffer full
        cpy     #BAS_LINBUF_SIZE
        bcs     @waitchar
        ; Store character
        sta     buffer,y
        iny
        jmp     @waitchar

@check_break:
        lda     program_state           ; Only break when a program is running
        bne     @waitchar               ; PS_READY (non-zero): discard and keep waiting
        lda     #ERR_STOPPED
        jmp     on_raise

@backspace:
        cpy     #0
        beq     @waitchar               ; Nothing to delete
        dey
        jmp     @waitchar

@done:
        lda     #0
        sta     buffer,y                ; Null-terminate
        lda     #CH_LF
        jsr     putch                   ; Echo newline (Chrin echoed the CR)
        rts

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

; putch -- output one character, but first poll for ESC or CTRL-C so the
; user can break out of a running BASIC program.  The check is skipped when
; the program is not running (PS_READY) to avoid eating characters typed at
; the READY prompt before readline is called.
putch:
        pha                             ; Save character to output
        lda     program_state           ; Only poll keyboard while a program is running
        bne     @output                 ; PS_READY (non-zero): skip break check
        jsr     Chrin                   ; Non-blocking poll (C=1 if char available)
        bcc     @output                 ; Nothing in the buffer
        cmp     #CH_ESC
        beq     @break
        cmp     #CH_CTRLC
        bne     @output                 ; Not a break key; discard and continue
@break:
        pla                             ; Discard the saved character
        lda     #ERR_STOPPED
        jmp     on_raise
@output:
        pla                             ; Restore character
        jmp     CHROUT

newline:
        lda     #CH_CR
        jsr     putch
        lda     #CH_LF
        jmp     putch

.code
        