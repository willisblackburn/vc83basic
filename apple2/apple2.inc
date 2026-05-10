; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

H2          := $2C
V2          := $2D
PROMPT      := $33      ; GETLN prompt character
COUTMASK    := $50
HIMEM       := $73      ; Highest available memory address+1

DOSWARM     := $03D0    ; DOS warmstart vector
BRKVEC      := $03F0    ; Break vector
SOFTEV      := $03F2    ; Vector for warm start
PWREDUP     := $03F4    ; This must be = EOR #$A5 of SOFTEV+1

LCRAMWP     := $C080    ; Select RAM + write protect RAM
LCROM       := $C081    ; Select ROM
LCROMWP     := $C082    ; Select ROM + write protect RAM
LCRAM       := $C083    ; Select RAM (read twice to write-enable RAM)

PLOT        := $F800
HLINE       := $F819
VLINE       := $F828
CLRSCR      := $F832
CLRTOP      := $F836
SETCOL      := $F864
SCRN        := $F871
SETTXT      := $FB39
PREAD       := $FB1E
SETGR       := $FB40
HOME        := $FC58
KEYIN       := $FD1B
GETLN       := $FD6A
GETLNNOPMPT := $FD6F
CROUT       := $FD8E
COUT        := $FDED
