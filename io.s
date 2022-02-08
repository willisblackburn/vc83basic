; cc65 runtime
.include "zeropage.inc"
.import push0, push1, pushax

; sim65 vectors
.import _read, _write

.export getline, getchar, putline, putline_buffer, putchar

; 255-byte buffer for I/O functions
buffer := $0200
; Use the last byte of the BUFFER page for character I/O operations.
io_char := $02FF

; Reads a line from the console into the buffer.
; Returns the length in A.

getline:
        ldy     #0              ; Use Y to track write index
@next:
        tya                     ; Save Y before calling functions
        pha
        jsr     getchar         ; Read one character
        cmp     #$0A            ; EOL?
        beq     @done           ; Yes
        tax                     ; Restore Y while preserving A
        pla
        tay
        txa    
        sta     buffer,y        ; Otherwise store character in buffer
        iny                     ; Increment write index
        jmp     @next
@done:
        pla
        rts

; Reads a single character from the console.
; Returns the character in A.

getchar:
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
; The putline_ptr1 entry point writes from the buffer address in ptr1.
; Inputs:
; AX = a pointer to the buffer to write (putline_buffer sets this to buffer)
; Y = the number of bytes to write

putline_buffer:
        lda     #<buffer
        ldx     #>buffer
putline:
        sta     ptr1
        stx     ptr1+1
        tya
        pha                     ; Park the length
        jsr     push1           ; File descriptor 1 (stdout)
        lda     ptr1
        ldx     ptr1+1
        jsr     pushax          ; Push buffer pointer onto C stack
        pla                     ; Length back into A
        ldx     #0              ; High byte of length
        jsr     _write
        rts

; Writes a single character to the console.
; Inputs:
; A = the character to output

putchar:
        sta     io_char         ; Store character in io_char
        jsr     push1           ; File descriptor 1 (stdout)
        lda     #<io_char       ; Load io_char address into AX
        ldx     #>io_char
        jsr     pushax          ; Push onto C stack
        lda     #1              ; Length
        ldx     #0 
        jsr     _write
        rts
    


