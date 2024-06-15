.include "macros.inc"
.include "basic.inc"

; Functions to decode values from the token stream.
; We don't have to worry about errors since we're decoding what we previously encoded.
; For all functions, line_pos is the read position in line_ptr.

; Decodes a number and returns it in AX.

decode_number:
        inc     line_pos                ; Advance past number marker token
        inc     line_pos                ; Increment read position to high byte 
        ldy     line_pos                ; Load position of high byte into Y
        inc     line_pos                ; Increment read one position again
        lda     (line_ptr),y            ; Load the high byte of the number
        tax                             ; Move into X
        dey                             ; Decrement Y
        lda     (line_ptr),y            ; Get the low byte of the number into A
        rts     

; Decodes a variable name and set up name_ptr and name_length.

decode_variable:
        ldy     line_pos
        inc     line_pos                ; Skip past the token + length byte
        lda     (line_ptr),y            ; Load token + length byte
        and     #<~TOKEN_VAR            ; Clear the TOKEN_VAR bit
        sta     name_length             ; Sets up the length of the name
        lda     line_ptr                ; Start with line_ptr
        clc
        adc     line_pos                ; Add line_pos to set up name_ptr
        sta     name_ptr
        lda     line_ptr+1
        adc     #0                      ; Will leave carry clear since name_ptr calculation should not roll over
        sta     name_ptr+1
        lda     line_pos                ; Advance line_pos past the name
        adc     name_length
        sta     line_pos
        rts

; Decodes a single byte and returns it in A.
; The last instruction loads A, so this function will return with the Z and N flags set accordingly.

decode_byte:
        ldy     line_pos                ; Read line_pos into Y and increment
        inc     line_pos  
        lda     (line_ptr),y            ; Load and return the byte
        rts
