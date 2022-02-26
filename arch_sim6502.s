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

; Architecture-specific initializations
; We point the BRK handler to the brk_handler function here.

brk_vector := $FFFE

initialize_arch:
        lda     #<debug_handler
        sta     brk_vector
        lda     #>debug_handler
        sta     brk_vector+1
        rts

; Reads a line from the console into the buffer.
; Returns the length in A and also sets buffer_length.

readline:
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
        lda     #<buffer
        ldx     #>buffer
        ldy     buffer_length
write:
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
        sta     io_char         ; Store character in io_char
        lda     #<io_char       ; Load io_char address into AX
        ldx     #>io_char
        ldy     #1
        jmp     write

; Debugging helpers

.zeropage

save_pc: .res 2

.bss

save_a: .res 1
save_x: .res 1
save_y: .res 1
save_sp: .res 1

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

format: .byte "$%02X: A=%02X X=%02X Y=%02X SP=%02X", $0A, $00

; Prints the register values to stderr.
; Since this function calls the C library function fprintf, it saves all the C zero page registers and
; restores them before exiting.
; Although calling into the C library from an interrupt handler is normally asking for trouble, since sim65
; doesn't generate interrupts, this wil only be called by a BRK statement.

debug_handler:
        cld                     ; Clear decimal flag (just in case)
        sta     save_a          ; Save 6502 registers
        stx     save_x
        sty     save_y
        tsx                     ; Get stack pointer into X
        stx     save_sp         ; Save it so we can print it
        ldy     $102,x          ; PC low byte
        sty     save_pc
        ldy     $103,x          ; PC high byte
        dey                     ; Subtract 256 from PC; we will index with Y = 255 to get PC-1
        sty     save_pc+1
        ldx     #0              ; Prepare to save cc65 registers
        push16  sreg
        push8   tmp1
        push8   tmp2
        push16  ptr1
        push16  ptr2
        push16  ptr3
        push16  ptr4
        lda     _stderr         ; fprintf(stderr, ...
        ldx     _stderr+1
        jsr     pushax
        lda     #<format        ; format, ...
        ldx     #>format
        jsr     pushax
        ldy     #$FF
        lda     (save_pc),y     ; id, ...
        jsr     pusha0          
        lda     save_a          ; A, ...
        jsr     pusha0
        lda     save_x          ; X, ...
        jsr     pusha0
        lda     save_y          ; Y, ...
        jsr     pusha0
        lda     save_sp         ; SP)
        jsr     pusha0
        ldy     #14             ; 14 bytes on the C stack
        jsr     _fprintf
        ldx     #0              ; Prepare to restore cc65 registers
        pull16  ptr4
        pull16  ptr3
        pull16  ptr2
        pull16  ptr1
        pull8   tmp2
        pull8   tmp1
        pull16  sreg
        lda     save_a          ; Restore 6502 registers
        ldx     save_x
        ldy     save_y
        rti
