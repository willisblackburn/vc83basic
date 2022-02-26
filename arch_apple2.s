; cc65 runtime
.include "zeropage.inc"
.import push0, push1, pusha0, pushax

; sim65 vectors
.import _read, _write

; C standard library functions
.import _fprintf, _stderr

.include "basic.inc"

.bss

; 256-byte buffer for I/O functions
buffer: .res 256

; The length of the data currently in the buffer
buffer_length: .res 1

; A single-byte buffer for the char operations
io_char: .res 1

.code

KEYIN   = $FD1B
CROUT   = $FD8E
COUT    = $FDED

getchar = KEYIN
putchar = COUT
newline = CROUT

; Architecture-specific initializations

initialize_arch:
        lda     #'H'
        jsr     COUT
        lda     #'E'
        jsr     COUT
        lda     #'L'
        jsr     COUT
        lda     #'L'
        jsr     COUT
        lda     #'O'
        jsr     COUT
        jsr     CROUT
        rts

readline:
        rts

write_buffer:
write:
        rts
