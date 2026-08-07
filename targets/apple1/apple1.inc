; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

; Apple 1 PIA (6820) I/O registers at $D010-$D013.
; These addresses are used by the original Apple 1, Replica-1, APL1,
; and most Apple 1 emulators.

KBD     := $D010        ; Keyboard data register (bit 7 set = character available)
KBDCR   := $D011        ; Keyboard control register (bit 7 = key strobe)
DSP     := $D012        ; Display data register (write character with bit 7 set)
DSPCR   := $D013        ; Display control register
