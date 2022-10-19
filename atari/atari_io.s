.include "atari.inc"
.include "../macros.inc"
.include "../basic.inc"

buffer := $500

.bss

; One-byte buffer for read and write
io_char: .res 1

.code 

.import print_number

readline:
        mva     #<buffer, ICBAL
        mva     #>buffer, ICBAH
        mva     #0, ICBLL
        mva     #1, ICBLH               ; buffer is 256 bytes but leave one byte for terminator
        mva     #GETREC, ICCOM
        ldx     #0
        jsr     CIOV


        ; lda     buffer
        ; ldx     #0
        ; jsr     print_number
        ; jsr     newline

        ldx     ICBLL                   ; Load the number of bytes actually read
        dex
        lda     #0
        sta     buffer,x
        rts


        ; lda     ICBLL
        ; ldx     ICBLH
        ; jsr     print_number
        ; jsr     newline

        ; dex
        ; mva     #0, buffer
        ; rts

        ; sta     buffer,x                ; Store terminator
        ; rts

getchar:
        rts

write:
        sta     ICBAL
        stx     ICBAH
        sty     ICBLL
        mva     #0, ICBLH
        mva     #PUTCHR, ICCOM
        ldx     #0
        jmp     CIOV

newline:
        lda     #$9B

; Fall through

putchar:
        sta     io_char
        mva     #<io_char, ICBAL
        mva     #>io_char, ICBAH
        mva     #1, ICBLL
        mva     #0, ICBLH
        mva     #PUTCHR, ICCOM
        ldx     #0
        jmp     CIOV
