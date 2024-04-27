.include "macros.inc"
.include "basic.inc"

.bss

; The program line produced by the parser
line_buffer: .res 256
 
.code

; Reads a number from the buffer.
; If the first character is not a number, then return an error. Otherwise, read up to the first non-digit.
; buffer_pos = the read position in buffer
; Returns the number in AX, carry clear if ok, carry set if error

read_number:
        jsr     skip_whitespace         ; TODO: can check return here to see if it's a number
        ldy     buffer_pos              ; Use Y to index buffer (since AX will hold the number)
        lda     #0                      ; Intialize the value to 0
        tax
@next:
        pha                             ; Save A (low byte of value)
        lda     buffer,y    
        jsr     char_to_digit           ; X SAFE function
        sta     B                       ; Store the digit value
        pla                             ; Retrieve the low byte of value
        bcs     @finish                 ; If there was an error in char_to_digit, stop parsing
        iny                             ; No error, increment read position
        jsr     mul10                   ; Multiply the value by 10 (preserves Y)
        clc
        adc     B                       ; Add the digit value
        bcc     @next                   ; If carry clear then next digit
        inx                             ; Otherwise increment high byte
        jmp     @next

@finish:
        cpy     buffer_pos              ; Did we parse anything?
        beq     @nothing                ; Nope
        sty     buffer_pos              ; Update read position
        clc                             ; Clear carry to signal OK
        rts

@nothing:
        sec                             ; Set carry to signal error
        rts

; Converts the character in A into a digit.
; Returns the digit in A, carry clear if ok, carry set if error
; X SAFE, Y SAFE

char_to_digit:
        sec                             ; Set carry
        sbc     #'0'                    ; Subtract '0'; maps valid values to range 0-9 and other values to 10-255
        cmp     #10                     ; Sets carry if it's in the 10-255 range
        rts

; Tests the input against a keyword. The last letter of the keyword must have bit 7 set (but it is ignored
; in the comparison).
; AX = pointer to the keyword
; buffer_pos = the read position in buffer
; Returns carry clear if the keyword matched, carry set if it didn't match.

parse_keyword:
        stax    BC                      ; Keyword pointer into BC      
        jsr     skip_whitespace         ; Leaves buffer_pos in X
        ldy     #0                      ; Y will index the keyword
@compare:       
        lda     (BC),y                  ; Get keyword character
        and     #$7F                    ; Mask out the high bit
        cmp     buffer,x                ; Compare with character from buffer
        bne     @not_match              ; It's not a match (carry flag will be uncertain)
        lda     (BC),y                  ; Get keyword character again
        bmi     @match                  ; Last character so it's a match; carry will be set from cmp above
        inx                             ; Next position
        iny                     
        jmp     @compare

@match:
        inx                             ; Move past matched character
        stx     buffer_pos              ; Update read position
        clc                             ; On match the carry flag will be set to have to clear it
        rts

@not_match:
        sec
        rts

; Skip past any whitespace in the buffer. Returns the next character in A. The final value of buffer_pos is also left in X.
; buffer_pos = the read position (modified)
; Y SAFE, BC SAFE, DE SAFE

loop_skip_whitespace:
        inc     buffer_pos
skip_whitespace:
        ldx     buffer_pos              ; Use X to index buffer
        lda     buffer,x        
        cmp     #' '        
        beq     loop_skip_whitespace       
        rts
