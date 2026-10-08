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

; Performs extended I/O using OS API_XIO ($E01B).
; A = command, BC = arg1, DE = arg2
; channel = channel index (0..7)
; Returns carry clear if ok, carry set if error.
xio:
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

; Gets a single byte/key from channel or serial UART (blocking).
; Returns carry clear and byte in A if ok, carry set if error / EOF.

getch:
        lda     channel
        bpl     @serial_getch           ; Bit 7 clear: not set by command -> default serial UART
        and     #$07
        jsr     API_GET
        rts

@serial_getch:
        jsr     inkey
        bcs     @serial_getch
        rts

; Polls for a key from serial UART without blocking.
; Returns carry clear and byte in A if available, carry set if no byte.

inkey:
        lda     UART_RX_LEVEL
        beq     @no_key
        lda     UART_RX_DATA
        clc
        rts
@no_key:
        sec
        rts

; Outputs a single character to serial UART or channel.
; A = character

putch:
        pha
        lda     channel
        bpl     @serial_putch           ; Bit 7 clear: not set by command -> default serial UART
        and     #$07
        tax                             ; Channel in X
        pla
        sta     arg1                    ; Character in arg1
        txa                             ; Channel in A
        jsr     API_PUT
        rts

@serial_putch:
        pla
        pha
:       lda     UART_TX_LEVEL
        cmp     #8
        bcs     :-                      ; Wait if FIFO full
        pla
        sta     UART_TX_DATA
        clc
        rts

; Emits record delimiter (CR + LF).

newline:
        lda     #$0D                    ; Carriage Return
        jsr     putch
        lda     #$0A                    ; Line Feed
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

; Reads a text record (line) from channel or serial into buffer.
; NUL-terminates at EOL, returns length in A.

readline:
        bit     channel
        bmi     @channel_readline       ; Bit 7 set: channel was set by command -> OS channel

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
        cmp     #$20                    ; Ignore control chars < space
        bcc     @loop
        cpx     #BUFFER_SIZE-1
        bcs     @loop

        ; Standard character
        sta     buffer,x
        jsr     putch                   ; Echo
        inx
        jmp     @loop

@bs:
        cpx     #0
        beq     @loop                   ; Ignore backspace at start of line
        dex
        lda     #$08                    ; BS
        jsr     putch
        lda     #' '                    ; Space
        jsr     putch
        lda     #$08                    ; BS
        jsr     putch
        jmp     @loop

@cr:
        lda     #0
        sta     buffer,x                ; Null-terminate
        txa                             ; Return length in A
        pha
        jsr     newline                 ; Echo newline
        pla
        clc
        rts

@channel_readline:
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
        jsr     API_READ
        bcs     @read_err

        ; If count > 0 and last byte is EOL ($0A) or CR ($0D), strip it
        tay
        beq     @no_strip
        dey
        lda     buffer, y
        cmp     #$0A
        beq     @strip
        cmp     #$0D
        beq     @strip
        iny
        tya
        clc
        rts

@strip:
        tya
        clc
        rts

@no_strip:
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
        bpl     :+
        sec
        rts
:
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
        bcc     :+
        rts
:
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
        bpl     :+
        sec
        rts
:
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
        bcc     :+
        rts
:
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
