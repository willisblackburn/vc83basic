PROMPT      := $33      ; GETLN prompt character
COUTMASK    := $50
HIMEM       := $73      ; Highest available memory address+1

DOSWARM     := $03D0    ; DOS warmstart vector
BRKVEC      := $03F0    ; Break vector
SOFTEV      := $03F2    ; Vector for warm start
PWREDUP     := $03F4    ; This must be = EOR #$A5 of SOFTEV+1

KEYIN       := $FD1B
GETLN       := $FD6A
GETLNNOPMPT := $FD6F
CROUT       := $FD8E
COUT        := $FDED
