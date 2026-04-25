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
; hardware-reading functions return 0.

.setcpu "65C02"

; --- Parser name tables and argument parsers --------------------------------

.segment "PARSER"

ex_statement_name_table:
        name_table_entry "CLS"
:       name_table_entry "LOCATE"
            JUMP pvm_arg_2
:       name_table_entry "COLOR"
            JUMP pvm_arg_2
:       name_table_entry "SOUND"
            JUMP ex_pvm_arg_3
:       name_table_entry "VOL"
            JUMP pvm_expression
:       name_table_entry "PAUSE"
            JUMP pvm_expression
:       name_table_entry "WAIT"
            JUMP pvm_arg_2
:       name_table_entry "TIME"
:       name_table_entry "DATE"
:       name_table_entry "SETTIME"
            JUMP ex_pvm_arg_3
:       name_table_entry "SETDATE"
            JUMP ex_pvm_arg_4
:       name_table_entry "NVRAM"
            JUMP pvm_arg_2
:       name_table_entry "BANK"
            JUMP pvm_expression
:       name_table_entry "MEM"
:       name_table_entry "SYS"
            JUMP pvm_expression
:       name_table_end

; Helper PVM fragments for 3- and 4-argument statements.

ex_pvm_arg_4:
        CALL pvm_expression
        ARGSEP
ex_pvm_arg_3:
        CALL pvm_expression
        ARGSEP
        CALL pvm_expression
        ARGSEP
        JUMP pvm_expression

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

; Check for Ctrl-C / ESC in the keyboard buffer.  Raise ERR_STOPPED if found.
ex_break_check:
        jsr     Chrin                   ; Non-blocking (C=1 if a char is waiting)
        bcc     @done
        cmp     #CH_ESC
        beq     @brk
        cmp     #CH_CTRLC
        bne     @done
@brk:
        lda     #ERR_STOPPED
        jmp     on_raise
@done:
        rts

; ---------------------------------------------------------------------------
; Video statements: CLS, LOCATE, COLOR
; ---------------------------------------------------------------------------

exec_cls:
        bit     HW_PRESENT              ; HW_VID is bit 7
        bpl     @skip
        jmp     VideoClear
@skip:
        rts

exec_locate:
        jsr     evaluate_argument_list
        jsr     pop_int_fp0             ; col
        sta     D                       ; D = col
        jsr     pop_int_fp0             ; row
        tay                             ; Y = row
        ldx     D                       ; X = col
        bit     HW_PRESENT
        bpl     @skip
        jmp     VideoSetCursor
@skip:
        rts

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
        jsr     ex_break_check
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

exec_settime:
        jsr     evaluate_argument_list
        jsr     pop_int_fp0             ; ss
        sta     C                       ; C = seconds
        jsr     pop_int_fp0             ; mm
        sta     D                       ; D = minutes
        jsr     pop_int_fp0             ; hh
        sta     E                       ; E = hours
        lda     HW_PRESENT
        and     #HW_RTC
        bne     :+
        jmp     ex_no_device
:       lda     E                       ; A = hours
        ldx     D                       ; X = minutes
        ldy     C                       ; Y = seconds
        jmp     RtcWriteTime

exec_setdate:
        jsr     evaluate_argument_list
        jsr     pop_int_fp0             ; dd
        sta     B                       ; B = day
        jsr     pop_int_fp0             ; mm
        sta     C                       ; C = month
        jsr     pop_int_fp0             ; yy
        sta     D                       ; D = year
        jsr     pop_int_fp0             ; cc
        sta     RTC_BUF_CENT
        lda     HW_PRESENT
        and     #HW_RTC
        bne     :+
        jmp     ex_no_device
:       lda     B                       ; A = day
        ldx     C                       ; X = month
        ldy     D                       ; Y = year
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

; JOY(n) -- return joystick bitmask for port n (1 or 2); 0 if GPIO absent.
fun_joy:
        sta     D                       ; save port number
        lda     HW_PRESENT
        and     #HW_GPIO
        beq     @none
        lda     D
        cmp     #2
        bcs     @p2                     ; n >= 2 -> port 2
        jsr     ReadJoystick1
        ldx     #0
        rts
@p2:
        jsr     ReadJoystick2
        ldx     #0
        rts
@none:
        lda     #0
        tax
        rts

; INKEY(x) -- return ASCII code of a pending key, or 0 if none.
; The argument is ignored (vc83 functions require at least one arg).
fun_inkey:
        jsr     Chrin                   ; C=1 if char available
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
