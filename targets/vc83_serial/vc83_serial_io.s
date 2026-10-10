; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

; Opens a channel using OS API_OPEN ($E006).
; S0 = filename string, length in (BC)
; A = open mode (e.g. 0=read, 1=write, $32=console layer 3, etc.)
; channel = channel index (0..7)
; Returns carry clear if ok, carry set if error.
open:
        sta     arg1                    ; Mode in arg1
        ldy     #0
        lda     (BC), y                 ; Length
        sta     arg4                    ; Length in arg4
        lda     S0
        sta     arg2                    ; String ptr low
        lda     S0+1
        sta     arg3                    ; String ptr high
        lda     channel
        and     #$07                    ; Channel 0..7
        jsr     API_OPEN
        rts

; Closes a channel using OS API_CLOSE ($E009).
; channel = channel index (0..7)
; Returns carry clear if ok, carry set if error.
close:
        lda     channel
        and     #$07
        jsr     API_CLOSE
        rts

; Closes all open channels (1..7).
close_all:
        ldx     #7
@loop:
        txa
        pha
        jsr     API_CLOSE
        pla
        tax
        dex
        bne     @loop
        rts

; ===========================================================================
; ensure_channel_0
;
; If the default channel is active (bit 7 of channel is clear), checks if
; channel #0 is open (IOCB 0 at $0200 has bit 7 set). If not, auto-opens
; the console "C:" with mode $32 on channel #0.
; Preserves A, X, Y.
; ===========================================================================
ensure_channel_0:
        bit     channel
        bmi     @done                   ; Explicit channel: do not auto-open
        bit     $0200                   ; Check IOCB 0 device byte
        bmi     @done                   ; Bit 7 is 1 -> already open
        pha
        txa
        pha
        tya
        pha
        lda     #(3 << 5) | OPEN_READ_WRITE ; Layer 3, Read/Write ($62)
        sta     arg1
        lda     #<console_filename
        sta     arg2
        lda     #>console_filename
        sta     arg3
        lda     #console_filename_len
        sta     arg4
        lda     #0                      ; Channel 0
        jsr     API_OPEN
        pla
        tay
        pla
        tax
        pla
@done:
        rts

; Performs extended I/O using OS API_XIO ($E01B).
; A = command, BC = arg1, DE = arg2
; channel = channel index (0..7)
; Returns carry clear if ok, carry set if error.
xio:
        jsr     ensure_channel_0
        sta     arg1
        lda     BC
        sta     arg2
        lda     BC+1
        sta     arg3
        lda     DE
        sta     arg4
        lda     channel
        and     #$07
        jsr     API_XIO
        rts

; Gets a single byte/key from channel (blocking).
; Returns carry clear and byte in A if ok, carry set if error / EOF.
getch:
        jsr     ensure_channel_0
        lda     channel
        and     #$07
        jsr     API_GET
        rts

; Polls for a key without blocking using API_STATUS.
; Returns carry clear and byte in A if available, carry set if no byte.
inkey:
        jsr     ensure_channel_0
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
        jsr     ensure_channel_0
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
        lda     #' '
        jsr     putch
        dex
        bne     @tab_loop
        clc
        rts

; Reads a text record (line) from channel into buffer.
; NUL-terminates at EOL, returns length in A.
readline:
        jsr     ensure_channel_0
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

        jsr     clear_variables
        jsr     reset_program
        clc
        rts

@load_format_err:
        jsr     initialize_program
        sec
        rts
