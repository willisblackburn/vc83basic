; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn / 2026 A.C. Wright
;
; SPDX-License-Identifier: MIT
;
; ac6502 target include -- symbolic names for BIOS Kernal routines and
; system variables used by VC83 BASIC.  Mirrors the Kernal ABI as of
; BIOS v1.5; see 6502-BIOS/BIOS.inc and the "Cartridge Support" section
; of its README for the full documentation.
;
; See https://github.com/acwright/6502-BIOS for more info

; The machine is a WDC 65C02S.  basic_ac6502.s includes this file first, so
; the setting covers the whole translation unit.  The shared core is written
; in plain 6502 and assembles identically either way; the target's own
; startup, I/O and BASIC extensions may use the 65C02 additions.
.setcpu "65C02"

CH_CTRLC            = $03
CH_BEL              = $07
CH_BKSP             = $08
CH_LF               = $0A
CH_CR               = $0D
CH_ESC              = $1B
CH_SPACE            = $20
CH_DEL              = $7F

; --- Zero-page system pointers (BIOS) ---
READ_PTR            := $00               ; Input ring buffer read cursor
WRITE_PTR           := $01               ; Input ring buffer write cursor (IRQ owns it)
STR_PTR             := $02               ; $02-$03 - BIOS string pointer

; --- BIOS Kernal jump table ($A000-$A0FF) ---
; Every entry is a stable 3-byte JMP; the addresses do not move between BIOS
; versions, so this table is safe to list in full even where VC83 does not
; (yet) call an entry.
Chrout              := $A000             ; Output character (routed by IO_MODE)
Chrin               := $A003             ; Input char, ECHOES it (see get_key in ac6502_io.s)
WriteBuffer         := $A006
ReadBuffer          := $A009
BufferSize          := $A00C
SetIOMode           := $A00F
GetIOMode           := $A012
InitVideo           := $A015
VideoClear          := $A018
VideoPutChar        := $A01B
VideoSetCursor      := $A01E
VideoGetCursor      := $A021
VideoScroll         := $A024
VideoSetColor       := $A027
VideoChroutRaw      := $A02A
InitSID             := $A02D
Beep                := $A030
SidPlayNote         := $A033
SidSilence          := $A036
SidSetVolume        := $A039
FsLoadFile          := $A03C
FsSaveFile          := $A03F
FsDeleteFile        := $A042
InitKB              := $A045
ReadJoystick1       := $A048
ReadJoystick2       := $A04B
InitSC              := $A04E
SerialChrout        := $A051
XModemLoad          := $A054
XModemSave          := $A057
RtcReadTime         := $A05A
RtcReadDate         := $A05D
RtcWriteTime        := $A060
RtcWriteDate        := $A063
RtcReadNVRAM        := $A066
RtcWriteNVRAM       := $A069
StReadSector        := $A06C
StWriteSector       := $A06F
StWaitReady         := $A072
SysDelay            := $A075
KernalInit          := $A078             ; Initialize all hardware; caller resets SP, must CLI after
KernalVersion       := $A07B
; --- Added in BIOS v1.1: disk banking and addressed storage ---
FsLoadFileAddr      := $A07E
FsSaveFileAddr      := $A081
FsFormatDisk        := $A084
FsSetDisk           := $A087
FsGetDisk           := $A08A
FsPrintDisk         := $A08D
; --- Added in BIOS v1.1: console output helpers ---
PrintStr            := $A090
PrintCRLF           := $A093
PrintDecU16         := $A096
; --- Added in BIOS v1.4: raw keyboard-encoder control ---
KBDisable           := $A099
KBEnable            := $A09C

; --- System RAM variables used here ---
INPUT_BUFFER        := $0200             ; $0200-$02FF - BIOS keyboard/serial ring buffer
IRQ_PTR             := $0300
BRK_PTR             := $0302
NMI_PTR             := $0304
IO_MODE             := $0306
VID_CURSOR_X        := $0307
VID_CURSOR_Y        := $0308
RTC_BUF_CENT        := $030B             ; Century register for RTC read/write
HW_PRESENT          := $030D
FS_FILE_SIZE        := $034A             ; 2 bytes - File size in bytes
BOOT_VECTOR         := $035B
FS_IO_ADDR          := $037F             ; 2 bytes - Load/save transfer address

; Legacy aliases used by earlier ac6502 code.
CHROUT              := Chrout
CHRIN               := Chrin

; --- HW_PRESENT bit masks ---
; Video is bit 7 on purpose: BIT HW_PRESENT tests it in N without disturbing A.
HW_RAM_L            = %00000001
HW_RAM_H            = %00000010
HW_RTC              = %00000100
HW_CF               = %00001000
HW_SC               = %00010000
HW_GPIO             = %00100000
HW_SID              = %01000000
HW_VID              = %10000000

; --- Hardware registers touched directly ---
RAM_BANK_L          := $83FF             ; Write-only bank latch for low RAM card
SC_CMD              := $9002             ; Serial card (R65C51) command register
SC_CMD_RX_READY     = $09                ; No parity/echo, RTSB low, RX interrupts on

; --- BASIC extension tokens and macros ---
TOK_CLS     = $60
TOK_LOCATE  = $61
TOK_COLOR   = $62
TOK_SOUND   = $63
TOK_VOL     = $64
TOK_PAUSE   = $65
TOK_WAIT    = $66
TOK_TIME    = $67
TOK_DATE    = $68
TOK_SETTIME = $69
TOK_SETDATE = $6A
TOK_NVRAM_W = $6B
TOK_BANK    = $6C
TOK_MEM     = $6D
TOK_SYS     = $6E

TOK_JOY     = $99
TOK_NVRAM_F = $9A

.macro extension_statement_keywords
:       name_table_entry "CLS"
:       name_table_entry "LOCATE"
:       name_table_entry "COLOR"
:       name_table_entry "SOUND"
:       name_table_entry "VOL"
:       name_table_entry "PAUSE"
:       name_table_entry "WAIT"
:       name_table_entry "TIME"
:       name_table_entry "DATE"
:       name_table_entry "SETTIME"
:       name_table_entry "SETDATE"
:       name_table_entry "NVRAM"
:       name_table_entry "BANK"
:       name_table_entry "MEM"
:       name_table_entry "SYS"
:       name_table_entry ""             ; Padding for even statement count
.endmacro


.macro extension_function_keywords
:       name_table_entry "JOY"
:       name_table_entry "NVRAM"
.endmacro

.macro extension_pvm_statements
        BRANCH_IF TOK_CLS, @done
        BRANCH_IF TOK_LOCATE, pvm_arg_2
        BRANCH_IF TOK_COLOR, pvm_arg_2
        BRANCH_IF TOK_SOUND, pvm_arg_3
        BRANCH_IF TOK_VOL, pvm_expression
        BRANCH_IF TOK_PAUSE, pvm_expression
        BRANCH_IF TOK_WAIT, pvm_arg_2
        BRANCH_IF TOK_TIME, @done
        BRANCH_IF TOK_DATE, @done
        BRANCH_IF TOK_SETTIME, pvm_arg_3
        BRANCH_IF TOK_SETDATE, pvm_arg_4
        BRANCH_IF TOK_NVRAM_W, pvm_arg_2
        BRANCH_IF TOK_BANK, pvm_expression
        BRANCH_IF TOK_MEM, @done
        BRANCH_IF TOK_SYS, pvm_expression
.endmacro

.macro extension_pvm_code
pvm_arg_4:
        CALL    pvm_expression
        MATCH   TOK_COMMA
        JUMP    pvm_arg_3
.endmacro

.macro extension_pvm_functions
        BRANCH_IF_RANGE TOK_JOY, 2, pvm_fun_1
.endmacro

.macro extension_statement_vectors_l
        .byte   <(exec_cls-1)
        .byte   <(exec_locate-1)
        .byte   <(exec_color-1)
        .byte   <(exec_sound-1)
        .byte   <(exec_vol-1)
        .byte   <(exec_pause-1)
        .byte   <(exec_wait-1)
        .byte   <(exec_time-1)
        .byte   <(exec_date-1)
        .byte   <(exec_settime-1)
        .byte   <(exec_setdate-1)
        .byte   <(exec_nvram_w-1)
        .byte   <(exec_bank-1)
        .byte   <(exec_mem-1)
        .byte   <(exec_sys-1)
        .byte   0
.endmacro

.macro extension_statement_vectors_h
        .byte   >(exec_cls-1)
        .byte   >(exec_locate-1)
        .byte   >(exec_color-1)
        .byte   >(exec_sound-1)
        .byte   >(exec_vol-1)
        .byte   >(exec_pause-1)
        .byte   >(exec_wait-1)
        .byte   >(exec_time-1)
        .byte   >(exec_date-1)
        .byte   >(exec_settime-1)
        .byte   >(exec_setdate-1)
        .byte   >(exec_nvram_w-1)
        .byte   >(exec_bank-1)
        .byte   >(exec_mem-1)
        .byte   >(exec_sys-1)
        .byte   0
.endmacro

.macro extension_statement_flags
        .byte   0 | (PROLOG_POP_INT << 4)                               ; CLS, LOCATE
        .byte   PROLOG_POP_INT | (PROLOG_POP_INT << 4)                  ; COLOR, SOUND
        .byte   PROLOG_POP_INT | (PROLOG_POP_INT << 4)                  ; VOL, PAUSE
        .byte   PROLOG_POP_INT | (0 << 4)                               ; WAIT, TIME
        .byte   0 | (PROLOG_POP_INT << 4)                               ; DATE, SETTIME
        .byte   PROLOG_POP_INT | (PROLOG_POP_INT << 4)                  ; SETDATE, NVRAM
        .byte   PROLOG_POP_INT | (0 << 4)                               ; BANK, MEM
        .byte   PROLOG_POP_INT | (0 << 4)                               ; SYS, padding
.endmacro

.macro extension_function_vectors_l
        .byte   <(fun_joy-1)
        .byte   <(fun_nvram-1)
.endmacro

.macro extension_function_vectors_h
        .byte   >(fun_joy-1)
        .byte   >(fun_nvram-1)
.endmacro

.macro extension_function_flags
        .byte   (PROLOG_POP_INT | EPILOG_PUSH_INT) | ((PROLOG_POP_INT | EPILOG_PUSH_INT) << 4) ; JOY, NVRAM
.endmacro
