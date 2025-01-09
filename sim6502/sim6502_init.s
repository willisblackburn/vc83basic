; cc65 runtime
.import push0, push1, pushax, pusha0

; C standard library functions
.import _fprintf, _stderr

.include "../macros.inc"
.include "../basic.inc"

; Architecture-specific initializations that will be invoked from main (even for unit tests).
; We point the BRK handler to the debug_handler function here.

initialize_target:
        lda     #<debug_handler
        sta     $FFFE                   ; BRK vector low byte
        lda     #>debug_handler
        sta     $FFFF                   ; BRK vector high byte
        rts

; Buffers

.segment "BUFFERS"

buffer: .res BUFFER_SIZE
line_buffer: .res BUFFER_SIZE

; Primary stack
stack: .res PRIMARY_STACK_SIZE
; Operator stack
op_stack: .res OP_STACK_SIZE

; Debugging helpers

.zeropage

save_pc: .res 2

.bss

save_a: .res 1
save_x: .res 1
save_y: .res 1
save_sp: .res 1
save_flags: .res 1

flag_indicators: .res 8

.code

format: .byte "$%02X: A=%02X X=%02X Y=%02X BCDE=%08LX SP=%02X %.8s FPX:FP0t=%08LX:%08LX e=%02X s=%02X FP1t=%08LX:%08LX e=%02X s=%02X src_ptr=%04X dst_ptr=%04X", $0A, $00
flag_names: .byte "NV-BDIZC"

; Prints the register values to stderr.
; Although calling into the C library from an interrupt handler is normally asking for trouble, since sim65
; doesn't generate interrupts, this will only be called by a BRK statement.

debug_handler:
        cld                             ; Clear decimal flag (just in case)
        sta     save_a                  ; Save 6502 registers
        stx     save_x      
        sty     save_y      
        tsx                             ; Get stack pointer into X
        stx     save_sp                 ; Save it so we can print it
        ldy     $102,x                  ; PC low byte
        sty     save_pc     
        ldy     $103,x                  ; PC high byte
        dey                             ; Subtract 256 from PC; we will index with Y = 255 to get PC-1
        sty     save_pc+1       
        lda     $101,x                  ; Flags
        sta     save_flags
        ldy     #0
@next_flag:
        lda     flag_names,y            ; Store name in indicator string if flag on
        rol     save_flags
        bcs     @on
        lda     #'-'                    ; Store '-' indicator string if flag off
@on:
        sta     flag_indicators,y
        iny
        cpy     #8
        bne     @next_flag
        lda     _stderr                 ; fprintf(stderr, ...
        ldx     _stderr+1
        jsr     pushax
        lda     #<format                ; format, ...
        ldx     #>format
        jsr     pushax
        ldy     #$FF
        lda     (save_pc),y             ; id, ...
        jsr     pusha0          
        lda     save_a                  ; A, ...
        jsr     pusha0
        lda     save_x                  ; X, ...
        jsr     pusha0
        lda     save_y                  ; Y, ...
        jsr     pusha0
        lda     C                       ; CB, ...
        ldx     B
        jsr     pushax
        lda     E                       ; ED, ...
        ldx     D
        jsr     pushax
        lda     save_sp                 ; SP, ...
        jsr     pusha0
        lda     #<flag_indicators       ; flag_indicators)
        ldx     #>flag_indicators
        jsr     pushax           
        lda     FPX+2                   ; FP0 significand, ...
        ldx     FPX+3
        jsr     pushax
        lda     FPX
        ldx     FPX+1
        jsr     pushax
        lda     FP0t+2
        ldx     FP0t+3
        jsr     pushax
        lda     FP0t
        ldx     FP0t+1
        jsr     pushax
        lda     FP0e                    ; FP0 exponent, ...
        jsr     pusha0
        lda     FP0s                    ; FP0 sign, ...
        jsr     pusha0
        lda     FP1t+2
        ldx     FP1t+3
        jsr     pushax
        lda     FP1t
        ldx     FP1t+1
        jsr     pushax
        lda     FP1e                    ; FP0 exponent, ...
        jsr     pusha0
        lda     FP1s                    ; FP0 sign, ...
        jsr     pusha0
        lda     src_ptr                 ; src_ptr, ...
        ldx     src_ptr+1
        jsr     pushax
        lda     dst_ptr                 ; dst_ptr, ...
        ldx     dst_ptr+1
        jsr     pushax
        ldy     #44                     ; 44 bytes on the C stack
        jsr     _fprintf
        lda     save_a                  ; Restore 6502 registers
        ldx     save_x
        ldy     save_y
        rti
