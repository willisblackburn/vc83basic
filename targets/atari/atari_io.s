; SPDX-FileCopyrightText: 2026 Willis Blackburn and Daniel Serpell
;
; SPDX-License-Identifier: MIT

.bss

open_mode:      .res 1
k_get_vec:      .res 2

.code

; Computes IOCB index (0, $10, $20, ..., $70) from zero-page channel variable.
; Preserves A; returns IOCB index in X.

get_iocb_index:
        pha
        lda     channel
        and     #$07                    ; Channel 0..7 (maps default $80 -> 0)
        asl
        asl
        asl
        asl
        tax
        pla
        rts

; Copies string currently described in S0 (length in BC) to buffer with a $9B (EOL) terminator.

copy_s0_to_buffer_eol:
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
        lda     #$9B                    ; Atari EOL
        sta     buffer,y
        rts

; Opens a file on channel.
; channel = channel index (0..7), A = mode, S0 = filename string
; Returns carry clear if ok, carry set if error.

atari_mode_table:
        .byte   4, 8, 12, 9             ; 0=Read, 1=Write, 2=Update, 3=Append

open:
        sta     open_mode
        jsr     copy_s0_to_buffer_eol
        jsr     get_iocb_index          ; Sets IOCB index in X (0..$70) based on channel
        lda     #<buffer
        sta     ICBAL,x
        lda     #>buffer
        sta     ICBAH,x
        lda     open_mode
        cmp     #4                      ; Atari native mode?
        bcs     @atari_mode
        tay
        lda     atari_mode_table,y
@atari_mode:
        sta     ICAX1,x
        lda     #0
        sta     ICAX2,x
        lda     #3                      ; OPEN
        sta     ICCOM,x
        jsr     CIOV
        cpy     #128
        bcs     @err
        clc
        rts
@err:
        sec
        rts

; Closes channel.
; channel = channel index (0..7)
; Returns carry clear.

close:
        jsr     get_iocb_index          ; Sets IOCB index in X based on channel
        lda     #12                     ; CLOSE
        sta     ICCOM,x
        jsr     CIOV
        clc
        rts

; Closes all open channels (IOCBs 1..7).

close_all:
        ldx     #$70
@close_loop:
        lda     #12                     ; CLOSE
        sta     ICCOM,x
        jsr     CIOV
        txa
        sec
        sbc     #$10
        tax
        bne     @close_loop
        clc
        rts

; Scans HATABS for 'K' (Keyboard device) and saves K: get-byte handler address.

init_k_vector:
        ldx     #0
@find_k:
        lda     HATABS,x                ; Device letter in HATABS
        cmp     #'K'
        beq     @found
        inx
        inx
        inx
        cpx     #36
        bcc     @find_k
@found:
        lda     HATABS+1,x              ; Vector table low
        sta     src_ptr
        lda     HATABS+2,x              ; Vector table high
        sta     src_ptr+1
        ldy     #4
        lda     (src_ptr),y             ; GET-BYTE vector low byte
        sta     k_get_vec
        iny
        lda     (src_ptr),y             ; GET-BYTE vector high byte
        sta     k_get_vec+1
        rts

; Gets a single byte/key from channel (blocking).
; channel = channel (0..7 or $80)
; Returns carry clear and byte in A if ok, carry set if error / EOF.

getch:
        jsr     get_iocb_index          ; Sets IOCB index in X based on channel
        lda     #0
        sta     ICBLL,x
        sta     ICBLH,x
        lda     #7                      ; GET CHARACTERS (GET BYTE)
        sta     ICCOM,x
        jsr     CIOV
        cpy     #128
        bcs     @error
        clc
        rts
@error:
        sec
        rts

; Polls for a key from keyboard without blocking.
; Returns carry clear and ASCII char in A if key available, carry set if no key.

inkey:
        lda     CH                      ; Hardware key code register
        cmp     #$FF
        beq     @no_key
        lda     k_get_vec+1             ; Push high byte of K: get-byte vector
        pha
        lda     k_get_vec               ; Push low byte of K: get-byte vector
        pha
        rts                             ; Dispatches to K: handler, returns character in A with CLC
@no_key:
        sec
        rts

; Puts a single character on channel.
; channel = channel (0..7 or $80), A = ASCII character

putch:
        pha                             ; Save character to output
        lda     program_state           ; Only check break while running
        bne     @output
        lda     BRKKEY                  ; $11: 0 = Break pressed
        bne     @output
        inc     BRKKEY                  ; Acknowledge / clear break flag
        raise   ERR_STOPPED             ; Stop and return to READY
@output:
        pla                             ; Restore character
        jsr     get_iocb_index          ; Sets IOCB index in X based on channel
        tay                             ; Save char in Y
        lda     ICPTH,x                 ; Push device put-byte handler address
        pha
        lda     ICPTL,x
        pha
        tya                             ; Restore char in A
        rts                             ; Dispatches directly to device driver

; Reads a text record (line) from channel into buffer.
; channel = channel (0..7 or $80)
; Strips trailing $9B, NUL-terminates at EOL, returns length in A.

readline:
        jsr     get_iocb_index          ; Sets IOCB index in X based on channel
        lda     #<buffer
        sta     ICBAL,x
        lda     #>buffer
        sta     ICBAH,x
        lda     #$FF
        sta     ICBLL,x
        lda     #0
        sta     ICBLH,x
        lda     #5                      ; GET RECORD
        sta     ICCOM,x
        jsr     CIOV
        lda     ICBLL,x                 ; Number of bytes read
        tax
        dex                             ; Strip $9B EOL
        bmi     @empty
        lda     #0
        sta     buffer,x                ; NUL-terminate
        txa                             ; Return length in A
        clc
        rts
@empty:
        lda     #0
        sta     buffer
        clc
        rts

; Emits record delimiter (newline).

newline:
        lda     #$9B
        jmp     putch

; Emits field separator (tabs across zones).

tab:
:       lda     #' '
        jsr     putch
        lda     COLCRS                  ; Cursor column
        and     #$07                    ; 8-column tab zone
        bne     :-
        clc
        rts

; Saves program memory to file via CIO.
; S0 = filename string

save:
        jsr     copy_s0_to_buffer_eol
        ldx     #$70                    ; Use IOCB 7
        lda     #<buffer
        sta     ICBAL,x
        lda     #>buffer
        sta     ICBAH,x
        lda     #8                      ; Mode 8 (Write)
        sta     ICAX1,x
        lda     #0
        sta     ICAX2,x
        lda     #3                      ; OPEN
        sta     ICCOM,x
        jsr     CIOV
        cpy     #128
        bcs     @err

        lda     #<(__BSS_RUN__ + __BSS_SIZE__)
        sta     ICBAL,x
        lda     #>(__BSS_RUN__ + __BSS_SIZE__)
        sta     ICBAH,x
        sec
        lda     variable_name_table_ptr
        sbc     #<(__BSS_RUN__ + __BSS_SIZE__)
        sta     ICBLL,x
        lda     variable_name_table_ptr+1
        sbc     #>(__BSS_RUN__ + __BSS_SIZE__)
        sta     ICBLH,x
        lda     #11                     ; PUT CHARACTERS
        sta     ICCOM,x
        jsr     CIOV
        pha
        tya
        pha
        lda     #12                     ; CLOSE
        sta     ICCOM,x
        jsr     CIOV
        pla
        tay
        pla
        cpy     #128
        bcs     @err
        clc
        rts
@err:
        sec
        rts

; Loads program memory from file via CIO.
; S0 = filename string

load:
        jsr     copy_s0_to_buffer_eol
        ldx     #$70                    ; Use IOCB 7
        lda     #<buffer
        sta     ICBAL,x
        lda     #>buffer
        sta     ICBAH,x
        lda     #4                      ; Mode 4 (Read)
        sta     ICAX1,x
        lda     #0
        sta     ICAX2,x
        lda     #3                      ; OPEN
        sta     ICCOM,x
        jsr     CIOV
        cpy     #128
        bcs     @err

        lda     #<(__BSS_RUN__ + __BSS_SIZE__)
        sta     ICBAL,x
        lda     #>(__BSS_RUN__ + __BSS_SIZE__)
        sta     ICBAH,x
        sec
        lda     himem_ptr
        sbc     #<(__BSS_RUN__ + __BSS_SIZE__)
        sta     ICBLL,x
        lda     himem_ptr+1
        sbc     #>(__BSS_RUN__ + __BSS_SIZE__)
        sta     ICBLH,x
        lda     #7                      ; GET CHARACTERS
        sta     ICCOM,x
        jsr     CIOV
        cpy     #128
        bcc     @read_ok
        cpy     #$88                    ; EOF is expected
        bne     @close_err

@read_ok:
        lda     #12                     ; CLOSE
        sta     ICCOM,x
        jsr     CIOV

        ; Validate header
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

        jsr     clear_variables
        jsr     reset_program
        clc
        rts

@format_err:
        jsr     initialize_program
        sec
        rts

@close_err:
        lda     #12
        sta     ICCOM,x
        jsr     CIOV
@err:
        sec
        rts

; Device-specific control operation (XIO).
; channel = channel (0..7), A = command, BC = arg1, DE = arg2

xio:
        sta     open_mode
        jsr     get_iocb_index          ; Sets IOCB index in X based on channel
        lda     open_mode
        sta     ICCOM,x
        lda     BC
        sta     ICAX1,x
        lda     DE
        sta     ICAX2,x
        jsr     CIOV
        cpy     #128
        bcs     @err
        clc
        rts
@err:
        sec
        rts
