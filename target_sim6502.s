; cc65 runtime
.include "zeropage.inc"
.import push0, push1, pushax

; sim65 vectors
.import _read, _write, exit

.bss

; 256-byte buffer for I/O functions
buffer: .res 256

; The length of the data currently in the buffer
buffer_length: .res 1

; A single-byte buffer for the char operations
io_char: .res 1

; Reads a line from the console into the buffer.
; Returns the length in A and also sets buffer_length.

.code 

readline:
.export readline
        ldy     #0              ; Use Y to track write index
@next:
        sty     buffer_length   ; Store buffer_length; getchar will clobber Y
        jsr     getchar         ; Read one character
        ldy     buffer_length   ; Save to reload Y from buffer_length now
        cmp     #$0A            ; EOL?
        beq     @done           ; Yes
        sta     buffer,y        ; Otherwise store character in buffer
        iny                     ; Increment write index
        jmp     @next
@done:
        tya                     ; Return buffer_length in A
        rts

; Reads a single character from the console.
; Returns the character in A.

getchar:
.export getchar
        jsr     push0           ; File descriptor 0 (stdin)
        lda     #<io_char       ; Load io_char address into AX
        ldx     #>io_char
        jsr     pushax          ; Push onto C stack
        lda     #1              ; Length
        ldx     #0 
        jsr     _read
        lda     io_char         ; Get the character into A
        rts

; Writes a line to the console. Defaults to write from buffer.
; The write_ptr1 entry point writes from the buffer address in ptr1.
; AX = a pointer to the buffer to write (write_buffer sets this to buffer)
; Y = the number of bytes to write (write_buffer sets this to buffer_length)

write_buffer:
.export write_buffer
        lda     #<buffer
        ldx     #>buffer
        ldy     buffer_length
write:
.export write
        sta     ptr1
        stx     ptr1+1
        sty     tmp1            ; Park the length
        jsr     push1           ; File descriptor 1 (stdout)
        lda     ptr1
        ldx     ptr1+1
        jsr     pushax          ; Push buffer pointer onto C stack
        lda     tmp1            ; Length back into A
        ldx     #0              ; High byte of length
        jsr     _write
        rts

; Starts a new line on the console.

newline:
.export newline
        lda     #$0A            ; Load LF into A then fall through to putchar

; Writes a single character to the console.
; A = the character to output

putchar:
.export putchar
        sta     io_char         ; Store character in io_char
        lda     #<io_char       ; Load io_char address into AX
        ldx     #>io_char
        ldy     #1
        jmp     write
