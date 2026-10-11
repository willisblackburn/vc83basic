; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

; Reset handler.

on_reset:
        rts

enable_console:
        clc                             ; Carry clear to display READY prompt
        rts

; Gets a single byte/key from channel (blocking).
; channel = channel (0..7)
; Returns carry clear and byte in A if ok, carry set if error.

getch:
        jsr     inkey
        bcs     getch
        rts

; Polls for a key from console without blocking.
; Returns carry clear and ASCII char in A if key available, carry set if no key.

inkey:
        lda     $C000                   ; Read Apple II keyboard
        bpl     @no_key                 ; Bit 7 clear -> no key pressed
        bit     $C010                   ; Clear keyboard strobe
        and     #$7F                    ; Convert to standard ASCII
        clc
        rts
@no_key:
        sec
        rts

; Puts a single character on channel.
; channel = channel (0..7), A = ASCII character

putch:
        ora     #$80
        jmp     COUT

; Reads a text record (line) from console into buffer.
; Suppresses prompt, strips bit 7, NUL-terminates at CR, returns length in A.

readline:
        jsr     GETLNNOPMPT             ; Apple II ROM reads into buffer ($0200) without prompt, length in X
        lda     #0
        sta     buffer,x                ; Replace CR with NUL
        txa                             ; Save length in A
        pha
@loop:
        dex
        bmi     @done
        lda     buffer,x
        and     #$7F                    ; Strip high bit
        sta     buffer,x
        bpl     @loop                   ; Unconditional
@done:
        pla                             ; Restore length in A
        clc
        rts

; Emits record delimiter (newline).

newline = CROUT

; Emits field separator (tabs to next 16-column boundary).

tab:
:       lda     #' ' | $80
        jsr     COUT
        lda     $24                     ; Cursor horizontal position CH
        and     #$0F                    ; 16-column tab zones
        bne     :-
        clc
        rts

; Prints 16-bit word in AX as 4 hex digits (high byte first) using ROM PRBYTE.
; A = high byte, X = low byte

print_ax_hex:
        jsr     PRBYTE                  ; Print high byte hex
        txa                             ; Low byte into A
        jmp     PRBYTE                  ; Print low byte hex

; Emits CROUT, Ctrl-D, command string, filename, ",A$", and start address.
; AY = pointer to length-prefixed command string, BC = filename string pointer

emit_dos_command_and_addr:
        stay    src_ptr                 ; Save command string pointer
        mvaa    BC, dst_ptr             ; Save filename pointer in zero page
        jsr     CROUT
        lday    src_ptr
        jsr     print_string            ; Prints Ctrl-D + "BSAVE " or "BLOAD "
        lday    dst_ptr
        jsr     print_string            ; Prints filename
        lday    #addr_cmd
        jsr     print_string            ; Prints ",A$"
        lda     #>(__BSS_RUN__ + __BSS_SIZE__)
        ldx     #<(__BSS_RUN__ + __BSS_SIZE__)
        jmp     print_ax_hex            ; Prints address and returns

; Saves program memory to file via DOS CHR$(4) BSAVE.
; BC = filename string pointer

save:
        lday    #bsave_cmd
        jsr     emit_dos_command_and_addr
        lday    #len_cmd
        jsr     print_string            ; Prints ",L$"
        sec
        lda     variable_name_table_ptr
        sbc     #<(__BSS_RUN__ + __BSS_SIZE__)
        tax
        lda     variable_name_table_ptr+1
        sbc     #>(__BSS_RUN__ + __BSS_SIZE__)
        jsr     print_ax_hex            ; Prints hex length
        jsr     CROUT
        clc
        rts

; Loads program memory from file via DOS CHR$(4) BLOAD.
; BC = filename string pointer

load:
        lday    #bload_cmd
        jsr     emit_dos_command_and_addr
        jsr     CROUT

        ; Validate and re-index loaded program
        ldy     #3
@check_magic:
        lda     __BSS_RUN__ + __BSS_SIZE__,y
        cmp     vbas_header,y
        bne     @format_err
        dey
        bpl     @check_magic

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

        jmp     reset_program           ; Tail call: reset_program ends in RTS with C=0

@format_err:
        jsr     initialize_program
        sec
        rts

.ifdef enable_io_channels
; Device-specific control operation.

xio:
        clc
        rts
.endif

bsave_cmd:      .byte 7, 4, "BSAVE "
bload_cmd:      .byte 7, 4, "BLOAD "
addr_cmd:       .byte 3, ",A$"
len_cmd:        .byte 3, ",L$"

        