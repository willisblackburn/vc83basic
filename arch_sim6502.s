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
buffer_length: .res 1
io_char: .res 1

.code

; Architecture-specific initializations
; We point the BRK handler to the brk_handler function here.

brk_vector := $FFFE

initialize_arch:
        lda     #<brk_handler
        sta     brk_vector
        lda     #>brk_handler
        sta     brk_vector+1
        rts

; Reads a line from the console into the buffer.
; Returns the length in A and also sets buffer_length.

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
        sta     buffer_length   ; Save buffer length
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
; AX = a pointer to the buffer to write (putline_buffer sets this to buffer)
; Y = the number of bytes to write (putline_buffer sets this to buffer_length)

putline_buffer:
        lda     #<buffer
        ldx     #>buffer
        ldy     buffer_length
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

; Debugging helpers

.bss

savea: .res 1
savex: .res 1
savey: .res 1

.macro  push8   value
        lda     value
        pha 
.endmacro

.macro  push16  value
        push8   value
        push8   value+1
.endmacro

.macro  pull8   value
        pla
        sta     value
.endmacro

.macro  pull16  value
        pull8   value+1
        pull8   value
.endmacro

.code

format: .byte "A=%02X, X=%02X, Y=%02X, SP=%02X", $0A, $00

; Prints the register values to stderr.
brk_handler:
        php
        sta     savea
        stx     savex
        sty     savey
        push8   tmp1
        push8   tmp2
        push8   tmp3
        push8   tmp4
        push16  ptr1  
        push16  ptr2
        push16  sreg
        push16  regsave  
        lda     _stderr
        ldx     _stderr+1
        jsr     pushax
        lda     #<format
        ldx     #>format
        jsr     pushax
        lda     savea
        jsr     pusha0
        lda     savex
        jsr     pusha0
        lda     savey
        jsr     pusha0
        tsx
        txa
        jsr     pusha0
        ldy     #12             ; 12 bytes on the C stack
        jsr     _fprintf
        pull16  regsave
        pull16  sreg
        pull16  ptr2
        pull16  ptr1
        pull8   tmp4
        pull8   tmp3
        pull8   tmp2
        pull8   tmp1
        lda     savea
        ldx     savex
        ldy     savey
        plp
        rti
