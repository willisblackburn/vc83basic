.include "macros.inc"
.include "basic.inc"

; Functions to decode values from the token stream.
; Sometimes these functions will be called when one value has already been read and is in the A register;
; this will be noted.
; We don't have to worry about errors since we're decoding what we previously encoded.
; For all functions, lp is the read position in line_ptr.

; Decodes the next token and invokes an entry in a vector table.
;   1xxx xxxx -> 0 (variable)
;   01xx xxxx -> 1 (function)
;   001x xxxx -> 2 (integer literal)
;   0001 xxxx -> 3 (operator)
;   0000 xxxx -> 4 + xxxx (all others)
; vector_table_ptr = the table of vectors for dispatching; must be set up in advance!
; BC SAFE

decode_dispatch_next:
        ldy     lp                      ; Get the line position
        inc     lp                      ; Advance past the position
        lda     (line_ptr),y            ; Load the byte
        debug $00
        ldy     #0                      ; Y is the jump table index
        tax                             ; Store byte in X so we can get it back later; re-set flags from byte
@test_msb:
        bmi     @dispatch               ; MSB is set, dispatch using vector Y
        iny                             ; Otherwise advance X
        cpy     #4                      ; Done bit shifting?
        beq     @dispatch_other         ; Dispatch the other value
        rol     A                       ; Otehrwse rotate the value left
        bcc     @test_msb               ; Unconditional; MSB was clear so carry must be clear now too

@dispatch_other:
        txa                             ; Transfer the original byte (in the range $00-$0F) into A
        clc
        adc     #4                      ; Add 4, shifting range to $04-$13
        tay                             ; Vector number is in Y
@dispatch:
        jmp     invoke_indexed_vector_vt    ; Invoke the vector using the existng vector_table_ptr; X is still the byte

; Decodes a number and returns it in AX.

decode_number:
        inc     lp                      ; Increment read position to high byte 
        ldy     lp                      ; Load position of high byte into Y
        inc     lp                      ; Increment read one position again
        lda     (line_ptr),y            ; Load the high byte of the number
        tax                             ; Move into X
        dey                             ; Decrement Y
        lda     (line_ptr),y            ; Get the low byte of the number into A
        rts     

; Decodes a single byte and returns it in A.
; The last instruction loads A, so this function will return with the Z and N flags set accordingly.

decode_byte:
        ldy     lp                      ; Read lp into Y and increment
        inc     lp  
        lda     (line_ptr),y            ; Load and return the byte
        rts
