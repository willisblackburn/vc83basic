; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn / 2026 A.C. Wright
;
; SPDX-License-Identifier: MIT
;
; ac6502 console I/O.
;
; The Kernal's Chrin ($A003) echoes every byte it hands back -- it is the
; BIOS's line-input primitive, not a raw poll.  That is wrong for a break
; check (the key lands in the middle of a running program's output) and wrong
; for INKEY (the key appears on screen), and in both cases the byte is
; swallowed, so a later INPUT never sees it.  So this target reads the input
; ring buffer directly and decides for itself when to echo.
;
; See https://github.com/acwright/6502 for more info

.code

; ---------------------------------------------------------------------------
; Keyboard input primitives
; ---------------------------------------------------------------------------

; get_key -- take the next byte out of the BIOS input buffer, without echo.
; Out: C=1 and A = the byte if one was waiting, C=0 otherwise.
; X and Y are preserved.

get_key:
        phx
        jsr     BufferSize              ; A = unread bytes
        beq     @none
        jsr     ReadBuffer              ; A = the byte (clobbers X)
        pha
        ; Chrin also releases RTS once the buffer has drained.  Irq asserts it
        ; when the buffer passes $F0 and nothing else ever lets go again, so a
        ; serial console would accept one bufferful and then wedge for good if
        ; this were left out.
        lda     HW_PRESENT
        and     #HW_SC
        beq     @done                   ; No serial card -- nothing to release
        jsr     BufferSize
        cmp     #$B0
        bcs     @done                   ; Still nearly full -- keep RTS asserted
        lda     #SC_CMD_RX_READY
        sta     SC_CMD
@done:
        pla
        plx
        sec
        rts
@none:
        plx
        clc
        rts

; peek_key -- look at the next byte without removing it, so anything that is
; not a break key stays in the buffer for INPUT / INKEY.
; Out: C=1 and A = the byte if one is waiting, C=0 otherwise.
; X and Y are preserved.

peek_key:
        phx
        jsr     BufferSize
        beq     @none
        ldx     READ_PTR                ; Irq only ever advances WRITE_PTR, so a
        lda     INPUT_BUFFER,x          ;   non-zero count means this byte is ours
        plx
        sec
        rts
@none:
        plx
        clc
        rts

; check_break -- raise ERR_STOPPED if ESC or CTRL-C is waiting.  Any other key
; is left in the buffer.  X and Y are preserved; A is clobbered.

check_break:
        jsr     peek_key
        bcc     @done
        cmp     #CH_ESC
        beq     @break
        cmp     #CH_CTRLC
        bne     @done                   ; Not a break key -- leave it for INPUT
@break:
        jsr     get_key                 ; Consume the break key itself
        raise   ERR_STOPPED
@done:
        rts

; ---------------------------------------------------------------------------
; Line input
; ---------------------------------------------------------------------------

; readline -- collect a line into `buffer`, echoing as it is typed.
; Returns the length in A; the line is null-terminated.

readline:
        ldy     #0
@waitchar:
        jsr     get_key
        bcc     @waitchar
        cmp     #CH_CR                  ; End of line
        beq     @done
        cmp     #CH_ESC                 ; Break keys interrupt a running program
        beq     @check_break
        cmp     #CH_CTRLC
        beq     @check_break
        cmp     #CH_BKSP
        beq     @backspace
        cmp     #CH_DEL
        beq     @backspace
        cmp     #CH_SPACE
        bcc     @waitchar               ; Other control codes: discard
        cmp     #CH_DEL
        bcs     @waitchar               ; $80 and up: not printable here
        cpy     #MAX_LINE_LENGTH
        bcs     @waitchar               ; Line full: discard, and do not echo it
        sta     buffer,y
        iny
        jsr     putch_raw               ; Echo the character we kept
        jmp     @waitchar

@check_break:
        lda     program_state           ; Only break when a program is running
        bne     @waitchar               ; PS_READY (non-zero): discard and keep waiting
        raise   ERR_STOPPED

@backspace:
        cpy     #0
        beq     @waitchar               ; Nothing to delete
        dey
        lda     #CH_BKSP                ; BS, space, BS.  The BIOS's video Chrout
        jsr     putch_raw               ;   erases on BS by itself, but a serial
        lda     #CH_SPACE               ;   terminal only moves the cursor, so
        jsr     putch_raw               ;   spell the erase out and satisfy both.
        lda     #CH_BKSP
        jsr     putch_raw
        jmp     @waitchar

@done:
        lda     #0
        sta     buffer,y                ; Null-terminate
        lda     #CH_CR                  ; Echo the newline: we never echoed the CR
        jsr     putch_raw
        lda     #CH_LF
        jsr     putch_raw
        tya                             ; Return the line length
        rts

; ---------------------------------------------------------------------------
; Output
; ---------------------------------------------------------------------------

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

; putch -- output one character, polling for a break first so the user can
; stop a running BASIC program.  The poll only peeks, so a key that is not ESC
; or CTRL-C stays in the buffer for INPUT / INKEY rather than being eaten and
; echoed into the middle of the program's output.  Skipped entirely when no
; program is running, so it costs nothing at the READY prompt.

putch:
        pha                             ; Save the character to output
        lda     program_state
        bne     @output                 ; PS_READY (non-zero): nothing to break
        jsr     check_break             ; Does not return if a break key is waiting
@output:
        pla                             ; Restore the character

; putch_raw -- output one character with no break check, for echo and for
; anything else that has already decided about breaking.

putch_raw:
        jmp     CHROUT

newline:
        lda     #CH_CR
        jsr     putch
        lda     #CH_LF
        jmp     putch

.code
