; cc65 runtime
.import push0, push1, pusha0, pushax

; sim65 vectors
.import _read, _write, exit

.include "../macros.inc"
.include "../basic.inc"
.bss

; 256-byte buffer for I/O functions
buffer: .res 256

.code

; Reads a line from the console into the buffer.
; Returns the length in A.

readline:
        mva     #0, C                   ; Use C for buffer index (getchar does not use it)
@next:      
        jsr     getchar                 ; Read one character
        ldy     C
        inc     C
        cmp     #$0A                    ; EOL?
        beq     @done                   ; Yes
        sta     buffer,y                ; Otherwise store character in buffer
        jmp     @next       
@done:      
        lda     #0      
        sta     buffer,y                ; Store 0 at end of buffer
        tya                             ; Return buffer length in A
        rts

; Reads a single character from the console.
; Returns the character in A.
; BC SAFE

getchar:
        jsr     push0                   ; File descriptor 0 (stdin)
        ldax    #B                      ; Load the character into B
        jsr     pushax                  ; Push onto C stack
        ldax    #1                      ; Length
        jsr     _read       
        lda     B                       ; Get the character into A
        rts

; Writes a line to the console.
; AX = a pointer to the buffer to write
; Y = the number of bytes to write

write:
        stax    DE                      ; Save buffer pointer
        sty     C                       ; Save length
        jsr     push1                   ; File descriptor 1 (stdout)
        ldax    DE
        jsr     pushax                  ; Push buffer pointer onto C stack
        lda     C                       ; Low byte of length
        ldx     #0                      ; High byte of length
        jmp     _write      

; Starts a new line on the console.

newline:
        lda     #$0A                    ; Load LF into A then fall through to putchar

; Writes a single character to the console.
; A = the character to output

putchar:
        sta     B                       ; Save character into single-byte buffer
        ldax    #B                      ; Pointer to buffer
        ldy     #1
        jmp     write
