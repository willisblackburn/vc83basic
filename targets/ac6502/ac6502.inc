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

; The machine is a WDC 65C02S.  basic.s and main.s are included before this
; file and so stay plain 6502; everything after it -- the target's own startup,
; buffers, I/O and BASIC extensions -- may use the 65C02 additions.
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
HW_PRESENT          := $030D
BOOT_VECTOR         := $035B

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

; --- RTC variables used by kernal routines ---
RTC_BUF_CENT        := $030B             ; Century register for RTC read/write

; --- Hardware registers touched directly ---
RAM_BANK_L          := $83FF             ; Write-only bank latch for low RAM card
SC_CMD              := $9002             ; Serial card (R65C51) command register
SC_CMD_RX_READY     = $09                ; No parity/echo, RTSB low, RX interrupts on
