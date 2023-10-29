; cc65 runtime
.import push0, push1, pushax

; sim65 vectors
.import _read, _write

.zeropage

; Holds pointer for use by write
write_ptr: .res 2

; A single-byte buffer for the char operations
char_buffer: .res 1

.bss

; 256-byte buffer for I/O functions
buffer: .res 256
.export buffer

.code

; Reads a string from the console into the buffer and adds a terminating NUL.
; Returns the length of the line in A.

readline:
.export readline
        jsr     push0                   ; File descriptor 0 (stdin)
        lda     #<buffer                ; Load buffer address into AX
        ldx     #>buffer
        jsr     pushax                  ; Push onto C stack
        lda     #.sizeof(buffer)-1      ; Max length = buffer size - 1 byte for NUL
        ldx     #0
        jsr     _read                   ; Returns length in AX (will be <= 254)
        tax                             ; Length into X
        lda     #0
        sta     buffer-1,x              ; Add terminator (subtract 1 because last character is LF)
        txa                             ; Line length back to A for return
        rts

; Writes bytes to the console.
; AX = a pointer to the buffer to write
; Y = the length of the buffer

write:
.export write
        sta     write_ptr
        stx     write_ptr+1
        tya                             ; Save length on the stack
        pha
        jsr     push1                   ; File descriptor 1 (stdout)
        lda     write_ptr               ; Buffer address
        ldx     write_ptr+1
        jsr     pushax
        pla                             ; Length
        ldx     #0
        jmp     _write

; Starts a new line on the console.

newline:
.export newline
        lda     #$0A                    ; Load LF into A then fall through to putch

; Writes a single character to the console.
; A = the character to output

putch:
.export putch
        sta     char_buffer             ; Store character in char_buffer
        jsr     push1                   ; File descriptor 1 (stdout)
        lda     #<char_buffer           ; Load char_buffer address into AX
        ldx     #>char_buffer
        jsr     pushax                  ; Push onto C stack
        lda     #1                      ; Length
        ldx     #0
        jsr     _write
        rts
