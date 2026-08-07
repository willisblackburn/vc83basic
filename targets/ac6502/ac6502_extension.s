; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn / 2026 A.C. Wright
;
; SPDX-License-Identifier: MIT
;
; ac6502 BASIC extensions.  Adds hardware-specific statements and
; functions that mirror the Integer BASIC built into the 6502-BIOS:
; CLS, LOCATE, COLOR, SOUND, VOL, PAUSE, WAIT, TIME, DATE, SETTIME,
; SETDATE, NVRAM, BANK, MEM, SYS and JOY(), INKEY(), NVRAM().
;
; Missing hardware is handled gracefully: statements print "NO DEVICE"
; (or silently skip for video/sound commands, matching the BIOS); the
; hardware-reading functions return whatever the BIOS's own BASIC returns
; for an absent card -- 0 for NVRAM, $FF for JOY (the ports are active low,
; so 0 would mean every direction and button held at once).
;
; The 65C02 instruction set is enabled in ac6502.inc.

; --- Parser name tables and argument parsers --------------------------------

.segment "PARSER"

ex_statement_name_table:
        name_table_entry "CLS"
:       name_table_entry "LOCATE"
            JUMP pvm_arg_2
:       name_table_entry "COLOR"
            JUMP pvm_arg_2
:       name_table_entry "SOUND"
            JUMP pvm_arg_3
:       name_table_entry "VOL"
            JUMP pvm_expression
:       name_table_entry "PAUSE"
            JUMP pvm_expression
:       name_table_entry "WAIT"
            JUMP pvm_arg_2
:       name_table_entry "TIME"
:       name_table_entry "DATE"
:       name_table_entry "SETTIME"
            JUMP pvm_arg_3
:       name_table_entry "SETDATE"
            JUMP pvm_arg_4
:       name_table_entry "NVRAM"
            JUMP pvm_arg_2
:       name_table_entry "BANK"
            JUMP pvm_expression
:       name_table_entry "MEM"
:       name_table_entry "SYS"
            JUMP pvm_expression
:       name_table_end

ex_function_name_table:
        name_table_entry "JOY"
:       name_table_entry "INKEY"
:       name_table_entry "NVRAM"
:       name_table_end

; --- Statement dispatch vectors ---------------------------------------------

.segment "XVEC"

ex_statement_vectors:
        .word   exec_cls-1
        .word   exec_locate-1
        .word   exec_color-1
        .word   exec_sound-1
        .word   exec_vol-1
        .word   exec_pause-1
        .word   exec_wait-1
        .word   exec_time-1
        .word   exec_date-1
        .word   exec_settime-1
        .word   exec_setdate-1
        .word   exec_nvram_w-1
        .word   exec_bank-1
        .word   exec_mem-1
        .word   exec_sys-1

; --- Function dispatch table ------------------------------------------------

.segment "XFUNC"

ex_function_table:
        .word   fun_joy-1
        .byte   1 | PROLOG_POP_INT | EPILOG_PUSH_INT
        .word   fun_inkey-1
        .byte   1 | PROLOG_POP_INT | EPILOG_PUSH_INT
        .word   fun_nvram-1
        .byte   1 | PROLOG_POP_INT | EPILOG_PUSH_INT

; --- Implementations --------------------------------------------------------

.code

; ---------------------------------------------------------------------------
; Small utilities
; ---------------------------------------------------------------------------

; Print a null-terminated string pointed to by AX (no newline).
ex_print_cstr:
        stax    BC
        ldy     #0
@next:
        lda     (BC),y
        beq     @done
        jsr     putch
        iny
        bne     @next
@done:
        rts

; Print a null-terminated string pointed to by AX followed by a newline.
ex_print_cstr_nl:
        jsr     ex_print_cstr
        jmp     newline

; Print "NO DEVICE" + newline.
ex_no_device:
        ldax    #ex_str_no_device
        jmp     ex_print_cstr_nl

ex_str_no_device:
        .byte   "NO DEVICE", 0

; Print A as two decimal digits (A must be 0-99).
ex_print_2d:
        ldx     #0
@tens:
        cmp     #10
        bcc     @done
        sec
        sbc     #10
        inx
        bne     @tens                   ; unconditional (X was just incremented so it's non-zero)
@done:
        pha
        txa
        clc
        adc     #'0'
        jsr     putch
        pla
        clc
        adc     #'0'
        jmp     putch

; Print A as two hex digits.
ex_print_2h:
        pha
        lsr     a
        lsr     a
        lsr     a
        lsr     a
        jsr     ex_print_nib
        pla
        and     #$0F
ex_print_nib:
        cmp     #10
        bcc     @digit
        clc
        adc     #'A' - 10
        jmp     putch
@digit:
        clc
        adc     #'0'
        jmp     putch

; Convert AX (16-bit signed int) to FP0 and print as a number.
ex_print_ax:
        jsr     int_to_fp
        jmp     print_number

; ---------------------------------------------------------------------------
; Video statements: CLS, LOCATE, COLOR
; ---------------------------------------------------------------------------

exec_cls:
        bit     HW_PRESENT              ; HW_VID is bit 7
        bpl     @skip
        jmp     VideoClear
@skip:
        rts

; LOCATE row, col -- 0-23 and 0-39, range-checked as the BIOS's own BASIC does.
; VideoSetCursor computes row * 40 + col with no limit of its own, so a row
; past 51 would leave the cursor beyond the 960-byte name table and let the
; next PRINT scribble over the character set in the pattern table at VRAM $0800.
exec_locate:
        jsr     evaluate_argument_list
        jsr     pop_int_fp0             ; col
        cpx     #0
        bne     @range
        cmp     #40
        bcs     @range
        sta     D                       ; D = col
        jsr     pop_int_fp0             ; row
        cpx     #0
        bne     @range
        cmp     #24
        bcs     @range
        tay                             ; Y = row
        ldx     D                       ; X = col
        bit     HW_PRESENT
        bpl     @skip
        jmp     VideoSetCursor
@skip:
        rts
@range:
        raise   ERR_OUT_OF_RANGE

exec_color:
        jsr     evaluate_argument_list
        jsr     pop_int_fp0             ; bg
        and     #$0F
        sta     D                       ; D = bg nibble
        jsr     pop_int_fp0             ; fg
        asl     a
        asl     a
        asl     a
        asl     a
        ora     D                       ; (fg<<4) | bg
        bit     HW_PRESENT
        bpl     @skip
        jmp     VideoSetColor
@skip:
        rts

; ---------------------------------------------------------------------------
; Sound statements: SOUND voice, freq, dur / VOL n
; ---------------------------------------------------------------------------

exec_sound:
        jsr     evaluate_argument_list
        jsr     pop_int_fp0             ; dur -> AX
        pha                             ; push dur_lo on CPU stack
        txa
        pha                             ; push dur_hi on CPU stack
        jsr     pop_int_fp0             ; freq (Hz) -> AX (A=lo, X=hi)
        ; Convert Hz to SID register: reg = Hz*16 + Hz - Hz/4 (= Hz * 16.75)
        ; Matches the conversion in the BIOS BASIC BasCmdSound routine.
        sta     B                       ; B = Hz_lo (original)
        stx     C                       ; C = Hz_hi (original)
        lda     B                       ; copy into D:E for the shifted accumulator
        sta     D
        lda     C
        sta     E
        asl     D                       ; D:E = Hz * 16 (4 left shifts)
        rol     E
        asl     D
        rol     E
        asl     D
        rol     E
        asl     D
        rol     E
        clc                             ; D:E = Hz * 17
        lda     D
        adc     B
        sta     D
        lda     E
        adc     C
        sta     E
        lsr     C                       ; B:C = Hz / 4 (2 right shifts)
        ror     B
        lsr     C
        ror     B
        sec                             ; D:E = Hz * 17 - Hz/4 = Hz * 16.75
        lda     D
        sbc     B
        sta     D
        lda     E
        sbc     C
        sta     E
        ; Push converted SID freq (D=lo, E=hi) so we can pop voice next
        lda     E
        pha                             ; push freqHi on CPU stack
        lda     D
        pha                             ; push freqLo on CPU stack
        jsr     pop_int_fp0             ; voice (1-3) -> A
        dec     a                       ; convert to 0-indexed (0-2)
        sta     E                       ; E = voice
        lda     HW_PRESENT
        and     #HW_SID
        beq     @no_sid
        pla                             ; freqLo
        tax                             ; X = freqLo
        pla                             ; freqHi
        tay                             ; Y = freqHi
        lda     E                       ; A = voice (0-indexed)
        jsr     SidPlayNote
        pla                             ; dur_hi
        tax                             ; X = dur_hi
        pla                             ; dur_lo
        jsr     SysDelay
        jmp     SidSilence
@no_sid:
        pla                             ; discard freqLo
        pla                             ; discard freqHi
        pla                             ; discard dur_hi
        pla                             ; discard dur_lo
        rts

exec_vol:
        jsr     evaluate_argument_list
        jsr     pop_int_fp0             ; level
        sta     D
        lda     HW_PRESENT
        and     #HW_SID
        beq     @skip
        lda     D
        jmp     SidSetVolume
@skip:
        rts

; ---------------------------------------------------------------------------
; Timing statements: PAUSE n / WAIT addr, mask
; ---------------------------------------------------------------------------

exec_pause:
        jsr     evaluate_argument_list
        jsr     pop_int_fp0             ; count (AX = lo/hi centiseconds)
        jmp     SysDelay

exec_wait:
        jsr     evaluate_argument_list
        jsr     pop_int_fp0             ; mask
        sta     D                       ; D = mask
        jsr     pop_int_fp0             ; address
        stax    BC                      ; BC = pointer
@loop:
        jsr     check_break             ; WAIT can spin forever -- stay breakable
        ldy     #0
        lda     (BC),y
        and     D
        beq     @loop
        rts

; ---------------------------------------------------------------------------
; Time / date statements
; ---------------------------------------------------------------------------

exec_time:
        lda     HW_PRESENT
        and     #HW_RTC
        bne     :+
        jmp     ex_no_device
:       jsr     RtcReadTime             ; A=hours, X=minutes, Y=seconds
        phy                             ; save seconds
        phx                             ; save minutes
        jsr     ex_print_2d             ; hours
        lda     #':'
        jsr     putch
        pla                             ; minutes
        jsr     ex_print_2d
        lda     #':'
        jsr     putch
        pla                             ; seconds
        jsr     ex_print_2d
        jmp     newline

exec_date:
        lda     HW_PRESENT
        and     #HW_RTC
        bne     :+
        jmp     ex_no_device
:       jsr     RtcReadDate             ; A=day, X=month, Y=year; RTC_BUF_CENT=century
        pha                             ; save day (last out)
        phx                             ; save month
        phy                             ; save year (first out)
        lda     RTC_BUF_CENT
        jsr     ex_print_2d             ; century
        pla                             ; year
        jsr     ex_print_2d
        lda     #'-'
        jsr     putch
        pla                             ; month
        jsr     ex_print_2d
        lda     #'-'
        jsr     putch
        pla                             ; day
        jsr     ex_print_2d
        jmp     newline

; Only D and E survive a pop_int_fp0 (pop_fp0 is documented DE SAFE, not BC
; SAFE), and SETTIME has three values to hold, so the surplus goes on the CPU
; stack -- the same trick exec_sound uses.
exec_settime:
        jsr     evaluate_argument_list
        jsr     pop_int_fp0             ; ss
        pha
        jsr     pop_int_fp0             ; mm
        pha
        jsr     pop_int_fp0             ; hh
        sta     E                       ; E = hours
        lda     HW_PRESENT
        and     #HW_RTC
        bne     :+
        pla                             ; Unwind mm and ss before bailing out
        pla
        jmp     ex_no_device
:       pla
        tax                             ; X = minutes
        pla
        tay                             ; Y = seconds
        lda     E                       ; A = hours
        jmp     RtcWriteTime

; Four values, and only D and E survive a pop -- see exec_settime above.
exec_setdate:
        jsr     evaluate_argument_list
        jsr     pop_int_fp0             ; dd
        pha
        jsr     pop_int_fp0             ; mm
        pha
        jsr     pop_int_fp0             ; yy
        sta     E                       ; E = year
        jsr     pop_int_fp0             ; cc
        sta     RTC_BUF_CENT
        lda     HW_PRESENT
        and     #HW_RTC
        bne     :+
        pla                             ; Unwind mm and dd before bailing out
        pla
        jmp     ex_no_device
:       pla
        tax                             ; X = month
        pla                             ; A = day
        ldy     E                       ; Y = year
        jmp     RtcWriteDate

; ---------------------------------------------------------------------------
; NVRAM addr, value (write)
; ---------------------------------------------------------------------------

exec_nvram_w:
        jsr     evaluate_argument_list
        jsr     pop_int_fp0             ; value
        sta     D                       ; D = value
        jsr     pop_int_fp0             ; address
        sta     E                       ; E = address
        lda     HW_PRESENT
        and     #HW_RTC
        bne     :+
        jmp     ex_no_device
:       ldx     E                       ; X = address
        lda     D                       ; A = value
        jmp     RtcWriteNVRAM

; ---------------------------------------------------------------------------
; System statements: BANK, MEM, SYS
; ---------------------------------------------------------------------------

exec_bank:
        jsr     evaluate_argument_list
        jsr     pop_int_fp0             ; bank number
        sta     D                       ; D = bank
        lda     HW_PRESENT
        and     #HW_RAM_L
        bne     :+
        jmp     ex_no_device
:       lda     D
        sta     RAM_BANK_L
        rts

exec_mem:
        jsr     fun_fre                 ; A=lo, X=hi of free bytes
        jsr     ex_print_ax             ; print free bytes
        ldax    #ex_str_free
        jsr     ex_print_cstr_nl
        ldax    #ex_str_hw
        jsr     ex_print_cstr
        lda     #'$'
        jsr     putch
        lda     HW_PRESENT
        jsr     ex_print_2h
        jsr     newline
        ldax    #ex_str_io
        jsr     ex_print_cstr
        lda     IO_MODE
        beq     @video
        ldax    #ex_str_serial
        jmp     ex_print_cstr_nl
@video:
        ldax    #ex_str_video
        jmp     ex_print_cstr_nl

ex_str_free:    .byte   " FREE", 0
ex_str_hw:      .byte   "HW=", 0
ex_str_io:      .byte   "IO=", 0
ex_str_video:   .byte   "VIDEO", 0
ex_str_serial:  .byte   "SERIAL", 0

exec_sys:
        jsr     evaluate_argument_list
        jsr     pop_int_fp0             ; address
        stax    BC
        jsr     ex_sys_call
        rts
ex_sys_call:
        jmp     (BC)

; ---------------------------------------------------------------------------
; Functions
; ---------------------------------------------------------------------------

; JOY(n) -- return the joystick bitmask for port n (1 or 2).
; Both ports are active low -- pulled high through 1K, grounded by the stick's
; switches -- so a held button reads 0 and an untouched stick reads $FF.  That
; makes $FF, not 0, the honest answer for a port that is not fitted at all;
; 0 would claim every direction and button is held.  Matches FnJoy in the
; BIOS's own BASIC, down to raising an error for a port that does not exist.
fun_joy:
        cpx     #0                      ; High byte must be zero...
        bne     @range
        cmp     #1                      ; ...and the port must be 1 or 2
        beq     @port
        cmp     #2
        bne     @range
@port:
        sta     D                       ; Save the port number
        lda     HW_PRESENT
        and     #HW_GPIO
        beq     @absent
        lda     D
        cmp     #2
        beq     @p2
        jsr     ReadJoystick1
        ldx     #0
        rts
@p2:
        jsr     ReadJoystick2
        ldx     #0
        rts
@absent:
        lda     #$FF                    ; What an untouched stick reads
        ldx     #0
        rts
@range:
        raise   ERR_OUT_OF_RANGE

; INKEY(x) -- return ASCII code of a pending key, or 0 if none.
; The argument is ignored (vc83 functions require at least one arg).
; get_key rather than the Kernal's Chrin, which would echo the key to the
; screen on its way back.
fun_inkey:
        jsr     get_key                 ; C=1 if a key was waiting
        bcs     @got
        lda     #0
@got:
        ldx     #0
        rts

; NVRAM(addr) -- read RTC NVRAM byte; returns 0 if RTC absent.
fun_nvram:
        sta     D                       ; D = address
        lda     HW_PRESENT
        and     #HW_RTC
        beq     @none
        ldx     D                       ; X = address
        jsr     RtcReadNVRAM            ; returns byte in A
        ldx     #0
        rts
@none:
        lda     #0
        tax
        rts
