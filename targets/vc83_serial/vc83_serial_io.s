; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

; Reset handler. Closes all open channels (1..7).
; Also closes channel 0 if it was redirected to a file (not C: or K:).
on_reset:
        ldx     #7
@loop:
        txa
        pha
        jsr     API_CLOSE
        pla
        tax
        dex
        bne     @loop

        ; Check channel 0: if open to a file (not C: or K:), close it
        lda     $0200                   ; IOCB 0 device byte
        bpl     @done                   ; Bit 7 is 0 -> closed
        and     #$78                    ; Device table index << 3
        cmp     #(2 << 3)               ; Device 2 = C:
        beq     @done
        cmp     #(5 << 3)               ; Device 5 = K:
        beq     @done
        lda     #0                      ; Channel 0
        jsr     API_CLOSE
@done:
        rts

; ===========================================================================
; ensure_channel_0
;
; If the default channel is active (bit 7 of channel is clear), checks if
; channel #0 is open (IOCB 0 at $0200 has bit 7 set). If not, restores console
; via GRMODE 0 (which opens channel #0 to "C:" on Layer 2).
; ===========================================================================
ensure_channel_0:
        bit     channel
        bmi     @done                   ; Explicit channel: do not auto-open
        bit     $0200                   ; Check IOCB 0 device byte
        bmi     @done                   ; Bit 7 is 1 -> channel open
        lda     #0
        tax
        jsr     exec_grmode
@done:
        rts

; Gets a single byte/key from channel (blocking).
; Returns carry clear and byte in A if ok, carry set if error / EOF.
getch:
        lda     channel
        and     #$07
        jsr     API_GET
        rts

; Polls for a key without blocking using API_STATUS.
; Returns carry clear and byte in A if available, carry set if no byte.
inkey:
        lda     channel
        and     #$07
        jsr     API_STATUS
        bcs     @no_key
        tax                             ; Count of waiting keys in X
        beq     @no_key
        lda     channel
        and     #$07
        jsr     API_GET
        rts
@no_key:
        sec
        rts

; Outputs a single character to channel.
; A = character
putch:
        pha
        jsr     ensure_channel_0
        pla
        sta     arg1                    ; Character in arg1
        lda     channel
        and     #$07                    ; Channel in A
        jsr     API_PUT
        rts

; Emits record delimiter (NL).
newline:
        lda     #$0A                    ; Newline
        jmp     putch

; Emits field separator (tabs across zones).
tab:
        ldx     #4
@tab_loop:
        txa
        pha
        lda     #' '
        jsr     putch
        pla
        tax
        dex
        bne     @tab_loop
        clc
        rts

; Reads a text record (line) from channel into buffer.
; NUL-terminates at EOL, returns length in A.
readline:
        lda     #<buffer
        sta     arg1
        lda     #>buffer
        sta     arg2
        lda     #<BUFFER_SIZE
        sta     arg3
        lda     #>BUFFER_SIZE
        sta     arg4
        lda     channel
        and     #$07
        jsr     API_READLINE
        bcs     @read_err

        ; Replace trailing NL ($0A) with NUL
        tay
        beq     @empty
        dey
        lda     buffer, y
        cmp     #$0A
        bne     @no_nl
        lda     #0
        sta     buffer, y
        tya
        clc
        rts

@no_nl:
        iny
        lda     #0
        sta     buffer, y
        tya
        clc
        rts

@empty:
        lda     #0
        sta     buffer
        clc
        rts

@read_err:
        sec
        rts

; Saves program memory to file.
; S0 = filename string, length in (BC)
save:
        ; Check if Channel 7 is open by inspecting IOCB 7 ($02E0)
        lda     $02E0
        bpl     @channel_available
        sec
        rts
@channel_available:
        ; Open file on channel 7 for write
        ldy     #0
        lda     (BC), y                 ; String length
        sta     arg4
        lda     S0
        sta     arg2
        lda     S0+1
        sta     arg3
        lda     #OPEN_WRITE             ; 1
        sta     arg1
        lda     #7
        jsr     API_OPEN
        bcc     @open_ok
        rts
@open_ok:
        ; Write program from (__BSS_RUN__ + __BSS_SIZE__) to variable_name_table_ptr
        sec
        lda     variable_name_table_ptr
        sbc     #<(__BSS_RUN__ + __BSS_SIZE__)
        sta     arg3
        lda     variable_name_table_ptr+1
        sbc     #>(__BSS_RUN__ + __BSS_SIZE__)
        sta     arg4

        lda     #<(__BSS_RUN__ + __BSS_SIZE__)
        sta     arg1
        lda     #>(__BSS_RUN__ + __BSS_SIZE__)
        sta     arg2

        lda     #7
        jsr     API_WRITE
        php                             ; Save carry flag

        lda     #7
        jsr     API_CLOSE

        plp                             ; Restore carry flag
        rts

; Loads program memory from file.
; S0 = filename string, length in (BC)
load:
        ; Check if Channel 7 is open
        lda     $02E0
        bpl     @channel_available
        sec
        rts
@channel_available:
        ; Open file on channel 7 for read
        ldy     #0
        lda     (BC), y
        sta     arg4
        lda     S0
        sta     arg2
        lda     S0+1
        sta     arg3
        lda     #OPEN_READ              ; 0
        sta     arg1
        lda     #7
        jsr     API_OPEN
        bcc     @open_ok
        rts
@open_ok:
        ; Read into (__BSS_RUN__ + __BSS_SIZE__) up to (himem_ptr - start)
        sec
        lda     himem_ptr
        sbc     #<(__BSS_RUN__ + __BSS_SIZE__)
        sta     arg3
        lda     himem_ptr+1
        sbc     #>(__BSS_RUN__ + __BSS_SIZE__)
        sta     arg4

        lda     #<(__BSS_RUN__ + __BSS_SIZE__)
        sta     arg1
        lda     #>(__BSS_RUN__ + __BSS_SIZE__)
        sta     arg2

        lda     #7
        jsr     API_READ                ; Returns bytes read in A (low) and X (high)
        bcc     @read_ok

        pha
        lda     #7
        jsr     API_CLOSE
        pla
        sec
        rts

@read_ok:
        sta     src_ptr
        stx     src_ptr+1
        lda     #7
        jsr     API_CLOSE

        ; Verify size >= 4 + sizeof(Line) = 4 + 3 = 7
        lda     src_ptr+1
        bne     @check_magic
        lda     src_ptr
        cmp     #7
        bcc     @load_format_err

@check_magic:
        ; Verify "VBAS" header
        ldy     #3
@magic_loop:
        lda     __BSS_RUN__ + __BSS_SIZE__, y
        cmp     vbas_header, y
        bne     @load_format_err
        dey
        bpl     @magic_loop

        ; Update variable_name_table_ptr = (__BSS_RUN__ + __BSS_SIZE__) + bytes_read
        clc
        lda     src_ptr
        adc     #<(__BSS_RUN__ + __BSS_SIZE__)
        sta     variable_name_table_ptr
        lda     src_ptr+1
        adc     #>(__BSS_RUN__ + __BSS_SIZE__)
        sta     variable_name_table_ptr+1

        jsr     reset_program
        clc
        rts

@load_format_err:
        jsr     initialize_program
        sec
        rts
