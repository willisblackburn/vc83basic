.include "macros.inc"
.include "basic.inc"

; Functions to decode values from the token stream.
; For all functions, line_pos is the read position in line_ptr.

; Decodes a number and returns it in AX.

decode_number:
        ldax    line_ptr
        ldy     line_pos
        jsr     read_number             ; May fail with carry set
        sty     line_pos                ; Update line_pos
        rts

; Decodes a variable name and set up decode_name_ptr and decode_name_length.

decode_name:
        lda     line_pos                ; Add line_pos to line_ptr to get decode_name_ptr
        clc
        adc     line_ptr
        sta     decode_name_ptr
        lda     line_ptr+1
        adc     #0                      ; Will leave carry clear since decode_name_ptr calculation should not roll over
        sta     decode_name_ptr+1
        ldy     #0                      ; Search for the end of the name starting at position 0
@next:
        lda     (decode_name_ptr),y
        bmi     @last
        iny
        bne     @next

@last:
        iny                             ; Account for last character
        sty     decode_name_length
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
