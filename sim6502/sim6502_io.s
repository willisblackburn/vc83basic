; cc65 runtime
.import push0, push1, pusha0, pushax

; sim65 vectors
.import _read, _write

.include "../macros.inc"
.include "../basic.inc"

; Reads a string from the console into the buffer and adds a terminating NUL.
; Returns the length of the line in A.

readline:
        jsr     push0                   ; File descriptor 0 (stdin)
        lda     #<buffer                ; Load buffer address into AX
        ldx     #>buffer
        jsr     pushax                  ; Push onto C stack
        lda     #BUFFER_SIZE-1          ; Max length = buffer size - 1 byte for NUL
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
        stax    BC                      ; Temporarily save buffer address in BC
        tya                             ; Save length on the stack
        pha
        jsr     push1                   ; File descriptor 1 (stdout)
        ldax    BC                      ; Buffer address
        jsr     pushax
        pla                             ; Length
        ldx     #0
        jmp     _write

; Starts a new line on the console.

newline:
        lda     #$0A                    ; Load LF into A then fall through to putch

; Writes a single character to the console.
; A = the character to output

putch:
        sta     C                       ; Store character to output
        jsr     push1                   ; File descriptor 1 (stdout)
        lda     #C                      ; Use C as the output buffer
        jsr     pusha0                  ; Push onto C stack
        lda     #1                      ; Length
        ldx     #0
        jsr     _write
        rts
