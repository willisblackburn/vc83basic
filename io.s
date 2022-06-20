; cc65 runtime
.import push0, push1, pushax

; sim65 vectors
.import _read, _write

.zeropage

hold_ptr: .res 2

.bss

; 256-byte buffer for I/O functions
buffer: .res 256
.export buffer

; Length of data in buffer
buffer_length: .res 1
.export buffer_length

; A single-byte buffer for the char operations
io_char: .res 1

.code 

; Reads a line from the console into the buffer.
; Returns the length in A and also sets buffer_length.

readline:
.export readline
        lda     #0                      ; Initialize buffer_length to 0
        sta     buffer_length
@next:      
        jsr     getchar                 ; Read one character
        ldy     buffer_length           ; Use buffer_length as index
        cmp     #$0A                    ; EOL?
        beq     @done                   ; Yes
        sta     buffer,y                ; Otherwise store character in buffer
        inc     buffer_length           ; Increment buffer_length
        jmp     @next       
@done:      
        tya                             ; Return buffer_length in A
        rts

; Reads a single character from the console.
; Returns the character in A.

getchar:
.export getchar
        jsr     push0                   ; File descriptor 0 (stdin)
        lda     #<io_char               ; Load io_char address into AX
        ldx     #>io_char       
        jsr     pushax                  ; Push onto C stack
        lda     #1                      ; Length
        ldx     #0      
        jsr     _read       
        lda     io_char                 ; Get the character into A
        rts

; Writes a line to the console.
; AX = a pointer to the buffer to write
; Y = the number of bytes to write

write:
.export write
        sta     hold_ptr
        stx     hold_ptr+1
        tya
        pha                             ; Save the length on the stack
        jsr     push1                   ; File descriptor 1 (stdout)
        lda     hold_ptr       
        ldx     hold_ptr+1     
        jsr     pushax                  ; Push buffer pointer onto C stack
        pla                             ; Length back into A
        ldx     #0                      ; High byte of length
        jmp     _write      

; Starts a new line on the console.

newline:
.export newline
        lda     #$0A                    ; Load LF into A then fall through to putchar

; Writes a single character to the console.
; A = the character to output

putchar:
.export putchar
        sta     io_char                 ; Store character in io_char
        lda     #<io_char               ; Load io_char address into AX
        ldx     #>io_char
        ldy     #1
        jmp     write
