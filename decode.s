.include "macros.inc"
.include "basic.inc"

; Functions to decode values from the token stream.
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

; Decodes a variable name and set up match_ptr and match_length.

decode_name:
        lda     line_pos                ; Add line_pos to line_ptr to get match_ptr
        clc
        adc     line_ptr
        sta     match_ptr
        lda     line_ptr+1
        adc     #0                      ; Will leave carry clear since match_ptr calculation should not roll over
        sta     match_ptr+1
        ldy     #0                      ; Search for the end of the name starting at position 0
@next:
        lda     (match_ptr),y
        bmi     @last
        iny
        bne     @next

@last:
        iny                             ; Account for last character
        sty     match_length
        tya                             ; Add to line_pos; carry should be clear
        adc     line_pos
        sta     line_pos                ; Update line_pos
        rts

; Decodes a single byte and returns it in A.
; The last instruction loads A, so this function will return with the Z and N flags set accordingly.

decode_byte:
        ldy     line_pos                ; Read line_pos into Y and increment
        inc     line_pos  
        lda     (line_ptr),y            ; Load and return the byte
        rts
