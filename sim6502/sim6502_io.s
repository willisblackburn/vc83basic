; cc65 runtime
.import push0, push1, pusha0, pushax

; sim65 vectors
.import _read, _write, exit

.include "../target.inc"

.bss

; 256-byte buffer for I/O functions
buffer := $200

; The length of the data currently in the buffer
buffer_length: .res 1

output_buffer: .res 256
output_buffer_length: .res 1

; Reads a line from the console into the buffer.
; Returns the length in A and also sets buffer_length.
; TODO: do we need buffer_length?

.code

readline:
        ldy     #0                      ; Use Y to track write position
@next:      
        sty     buffer_length           ; Store buffer_length; getchar will clobber Y
        jsr     getchar                 ; Read one character
        ldy     buffer_length           ; Save to reload Y from buffer_length now
        cmp     #$0A                    ; EOL?
        beq     @done                   ; Yes
        sta     buffer,y                ; Otherwise store character in buffer
        iny                             ; Increment write position
        jmp     @next       
@done:      
        lda     #0      
        sta     buffer,y                ; Store 0 at end of buffer
        tya                             ; Return buffer_length in A
        rts

; Reads a single character from the console.
; Returns the character in A.

getchar:
        jsr     push0                   ; File descriptor 0 (stdin)
        ldax    #B                      ; Load the character into B
        jsr     pushax                  ; Push onto C stack
        lda     #1                      ; Length
        ldx     #0      
        jsr     _read       
        lda     B                       ; Get the character into A
        rts

; Writes a line to the console.
; The write_buffer entry point writes from buffer.
; AX = a pointer to the buffer to write (write_buffer sets this to buffer)
; Y = the number of bytes to write (write_buffer sets this to buffer_length)
; B SAFE

write_buffer:
        lda     #<buffer
        ldx     #>buffer
        ldy     buffer_length
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
        sta     B                       ; Use B as a single-byte buffer
        ldax    #B                      ; Pointer to B
        ldy     #1
        jmp     write
