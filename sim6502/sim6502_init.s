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

format: .byte "$%02X: A=%02X X=%02X Y=%02X SP=%02X FPA=%04X%04X-%04X%04X-%02X %.8s", $0A, $00
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
        lda     save_sp                 ; SP, ...
        jsr     pusha0
        lda     FPA+Float::significand+6    ; FPA significand, ...
        ldx     FPA+Float::significand+7
        jsr     pushax
        lda     FPA+Float::significand+4
        ldx     FPA+Float::significand+5
        jsr     pushax
        lda     FPA+Float::significand+2
        ldx     FPA+Float::significand+3
        jsr     pushax
        lda     FPA+Float::significand
        ldx     FPA+Float::significand+1
        jsr     pushax
        lda     FPA+Float::exponent     ; FPA exponent, ...
        jsr     pusha0
        lda     #<flag_indicators       ; flag_indicators)
        ldx     #>flag_indicators
        jsr     pushax           
        ldy     #26                     ; 26 bytes on the C stack
        jsr     _fprintf
        lda     save_a                  ; Restore 6502 registers
        ldx     save_x
        ldy     save_y
        rti
