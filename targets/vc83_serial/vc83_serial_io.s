; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

.segment "BSS"
default_channel: .res 1
.segment "CODE"

; ===========================================================================
; is_channel_0_other
;
; Checks if channel 0 is open to a non-console device (e.g. H: or a file).
; Returns carry set if open to other device, carry clear if closed or open to C:.
; ===========================================================================
is_channel_0_other:
        lda     $0200                   ; IOCB 0 device byte
        bpl     @not_other              ; Bit 7 is 0: closed (not other device)
        and     #$78                    ; Device table index << 3
        lsr                             ; Index * 4
        tax
        lda     $0300, x                ; Device letter in Device Table
        cmp     #'C'
        beq     @not_other              ; Open to C:: return carry clear
        sec                             ; Carry set: open to other device
        rts
@not_other:
        clc
        rts

; ===========================================================================
; enable_console
;
; Called by main interpreter (on_raise) when transitioning to PS_READY or error.
; A = new program_state (PS_READY or error code)
; Returns carry clear to display READY, carry set to suppress READY.
; ===========================================================================
enable_console:
        cmp     #ERR_STOPPED            ; Check if program was stopped by STOP/Ctrl-C
        beq     @check_suppress
        bpl     @check_suppress         ; Positive: normal termination (PS_READY)
        lda     default_channel         ; Error occurred; check if SOURCE is active
        beq     @ensure_active
        jsr     API_CLOSE               ; Close redirected default_channel (7)
        stz     default_channel
        bra     @ensure_active

@check_suppress:
        lda     default_channel         ; Check if input is redirected by SOURCE
        beq     @ensure_active
        sec                             ; Carry set suppresses READY / STOPPED
        rts

@ensure_active:
        ; 1. Check if channel 0 is closed
        lda     $0200                   ; Check IOCB 0 device byte
        bmi     @check_c                ; If open (bit 7 set) then check device
        ; Channel 0 closed: re-open C: via GRMODE 0
        lda     #0                      ; Re-open C: in default text mode 0
        tax
        jsr     exec_grmode
        clc                             ; Carry clear to display READY prompt
        rts

@check_c:
        ; 2. Channel 0 is open; check if it's C:
        jsr     is_channel_0_other      ; Check if channel 0 is open to other device
        bcs     @done                   ; Leave alone if open to other device (e.g., H:)

        ; Channel 0 is open to C:; make sure Layer 2 is visible if hidden
        lda     #$B0                    ; Select VCGA register bank
        sta     BANK_SELECT_D
        lda     $D04C                   ; VCGA_L2_MODE
        bne     @already_visible        ; Skip enabling if layer 2 is already active
        lda     #2                      ; Tilemap mode for layer 2
        sta     $D04C
@already_visible:
        lda     #$E0                    ; Restore standard bank
        sta     BANK_SELECT_D

@done:
        clc                             ; Carry clear to display prompt
        rts

; Reset handler. Closes all open channels (1..7).
on_reset:
        stz     default_channel         ; Clear redirected channel on reset
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
        ; Check if reading from default channel (channel == 0)
        lda     channel                 ; Check channel being read
        bne     @read_explicit          ; If non-zero (or bit 7 set), read channel directly

        ; Reading from default channel
        lda     default_channel         ; Check if input is redirected by SOURCE
        beq     @read_console_0

        ; default_channel != 0: read from default_channel (e.g. channel 7)
        lda     #<buffer
        sta     arg1
        lda     #>buffer
        sta     arg2
        lda     #<BUFFER_SIZE
        sta     arg3
        lda     #>BUFFER_SIZE
        sta     arg4
        lda     default_channel         ; Channel to read from
        jsr     API_READLINE            ; Read line from redirected channel
        bcs     @default_eof
        jmp     @format_line

@default_eof:
        ; EOF / error on default_channel: close it, clear default_channel, return EOF
        lda     default_channel         ; Channel that hit EOF
        jsr     API_CLOSE               ; Close redirected channel
        stz     default_channel         ; Reset default channel to 0
        sec                             ; Carry set indicates EOF
        rts

@read_console_0:
        ; Reading from console channel 0. If open to C:, ensure Layer 2 visible
        jsr     is_channel_0_other      ; Check if channel 0 is open to other device
        bcs     @do_read_0
        lda     #$B0                    ; Select VCGA register bank
        sta     BANK_SELECT_D
        lda     $D04C                   ; VCGA_L2_MODE
        bne     @already_visible        ; Skip enabling if layer 2 is already active
        lda     #2                      ; Tilemap mode for layer 2
        sta     $D04C
@already_visible:
        lda     #$E0                    ; Restore standard bank
        sta     BANK_SELECT_D

@do_read_0:
        lda     #0
        bra     @do_read

@read_explicit:
        lda     channel
        and     #$07                    ; Mask to 3-bit channel number (0..7)

@do_read:
        pha
        lda     #<buffer
        sta     arg1
        lda     #>buffer
        sta     arg2
        lda     #<BUFFER_SIZE
        sta     arg3
        lda     #>BUFFER_SIZE
        sta     arg4
        pla
        jsr     API_READLINE
        bcs     @read_err

@format_line:
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
