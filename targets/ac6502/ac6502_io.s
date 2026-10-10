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
; Console I/O interface
; ---------------------------------------------------------------------------
; Gets a single byte/key from console (blocking).
; Returns carry clear and byte in A if ok, carry set if error.

getch:
        jsr     inkey
        bcs     getch
        rts

; Polls for a key from console without blocking.
; Returns carry clear and ASCII char in A if key available, carry set if no key.

inkey:
        jsr     get_key                 ; C=1 if key available
        bcs     @got_key
        sec
        rts
@got_key:
        clc
        rts

; Puts a single character to the console.
; A = ASCII character
; Polls for ESC or CTRL-C while a BASIC program is running to allow break.

putch:
        pha                             ; Save character to output
        lda     program_state           ; Only poll keyboard while a program is running
        bne     @output                 ; PS_READY (non-zero): skip break check
        jsr     check_break             ; Does not return if a break key is waiting
@output:
        pla                             ; Restore character

; putch_raw -- output one character with no break check, for echo and for
; anything else that has already decided about breaking.

putch_raw:
        jmp     Chrout

; Emits record delimiter (CR + LF).

newline:
        lda     #CH_CR
        jsr     putch
        lda     #CH_LF
        jmp     putch

; Emits field separator (tabs across zones).

tab:
        bit     HW_PRESENT              ; Video present? (Bit 7 = HW_VID)
        bpl     @serial_tab
        lda     IO_MODE                 ; Video mode (0)?
        bne     @serial_tab
:       lda     #' '
        jsr     putch
        lda     VID_CURSOR_X
        and     #$07                    ; 8-column tab zone
        bne     :-
        clc
        rts
@serial_tab:
        ldx     #4
:       lda     #' '
        jsr     putch
        dex
        bne     :-
        clc
        rts

; Reads a text record (line) from console into buffer.
; NUL-terminates at EOL, returns length in A.

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
        clc
        rts

; ---------------------------------------------------------------------------
; Program storage (CompactFlash)
; ---------------------------------------------------------------------------

; Copies string currently described in S0 (length in BC) to buffer with a NUL terminator.

copy_s0_to_buffer_nul:
        ldy     #0
        lda     (BC),y                  ; Length byte
        tay
        beq     @empty
        tax                             ; Length in X
        ldy     #0
@loop:
        lda     (S0),y
        sta     buffer,y
        iny
        dex
        bne     @loop
@empty:
        lda     #0                      ; NUL terminator
        sta     buffer,y
        rts

; Saves program memory to file via CompactFlash filesystem.
; S0 = filename string

save:
        jsr     copy_s0_to_buffer_nul
        lda     #<buffer
        sta     STR_PTR
        lda     #>buffer
        sta     STR_PTR+1
        lda     #<(__BSS_RUN__ + __BSS_SIZE__)
        sta     FS_IO_ADDR
        lda     #>(__BSS_RUN__ + __BSS_SIZE__)
        sta     FS_IO_ADDR+1
        sec
        lda     variable_name_table_ptr
        sbc     #<(__BSS_RUN__ + __BSS_SIZE__)
        sta     FS_FILE_SIZE
        lda     variable_name_table_ptr+1
        sbc     #>(__BSS_RUN__ + __BSS_SIZE__)
        sta     FS_FILE_SIZE+1
        jsr     FsSaveFileAddr
        rts                             ; FsSaveFileAddr returns C=0 on success, C=1 on error

; Loads program memory from file via CompactFlash filesystem.
; S0 = filename string

load:
        jsr     copy_s0_to_buffer_nul
        lda     #<buffer
        sta     STR_PTR
        lda     #>buffer
        sta     STR_PTR+1
        lda     #<(__BSS_RUN__ + __BSS_SIZE__)
        sta     FS_IO_ADDR
        lda     #>(__BSS_RUN__ + __BSS_SIZE__)
        sta     FS_IO_ADDR+1
        jsr     FsLoadFileAddr
        bcs     @err                    ; Carry set = file not found or card error

        ; Validate header signature
        ldy     #3
@check_magic:
        lda     __BSS_RUN__ + __BSS_SIZE__,y
        cmp     vbas_header,y
        bne     @format_err
        dey
        bpl     @check_magic

        ; Walk line offsets to rebuild variable_name_table_ptr
        mvax    #(__BSS_RUN__ + __BSS_SIZE__ + 4), BC
        ldy     #Line::next_line_offset
@walk_loop:
        lda     (BC),y
        beq     @found_end
        clc
        adc     BC
        sta     BC
        bcc     @walk_loop
        inc     BC+1
        bne     @walk_loop
@found_end:
        clc
        lda     BC
        adc     #.sizeof(Line)
        sta     variable_name_table_ptr
        lda     BC+1
        adc     #0
        sta     variable_name_table_ptr+1

        jsr     reset_program
        clc
        rts

@format_err:
        jsr     initialize_program
        sec
        rts

@err:
        sec
        rts

