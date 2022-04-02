; cc65 runtime
.include "zeropage.inc"
.import jmpvec

.include "target.inc"
.include "basic.inc"

.zeropage

; Contains the error code when a function returns with the carry set
; to signal an error. May also be used to pass information about the outcome of a function,
; for example if a function completed successfully (carry clear) but had no effect.
status: .res 1

copy_from_ptr: .res 2
copy_to_ptr: .res 2
copy_length: .res 2

.code

; Copies bytes from a source address to a destination address.
; The source and destination byte ranges must not overlap unless the destination address is lower than the
; source address.
; Alters copy_from_ptr and copy_to_ptr.
; copy_from_ptr = source
; copy_to_ptr = destination (must be <=copy_from_ptr)
; copy_length = number of bytes to copy

copy_bytes:
        ldy     #0                  ; Y = 0 meaning 256 bytes per block
        ldx     copy_length+1       ; Number of 256-byte blocks
        beq     @remaining          ; If no blocks, just do remaining bytes
@next_byte:
        lda     (copy_from_ptr),y   ; Copy one byte
        sta     (copy_to_ptr),y            
        iny                         ; Next byte
        bne     @next_byte          ; More to move
        inc     copy_from_ptr+1     ; Add 256
        inc     copy_to_ptr+1       ; to both copy_from_ptr and copy_to_ptr
        dex                         ; Decrement number of blocks
        bne     @next_byte          ; Move to move

; Copy the remaining bytes.
; Y = 0 when we first reach this point

@remaining:
        cpy     copy_length         ; Compare Y with number of remaining bytes
        beq     @return             ; If equal then we're done
        lda     (copy_from_ptr),y   ; Otherwise move one more byte
        sta     (copy_to_ptr),y           
        iny
        jmp     @remaining          ; TODO: optimize for 65C02

@return:
        rts

; Copy bytes backwards from a source address to a destination address.
; Used when the source and destination byte ranges overlap and destination address is higher than the source address.
; Alters copy_from_ptr and copy_to_ptr.
; copy_from_ptr = source
; copy_to_ptr = destination (must be <=copy_from_ptr)
; copy_length = number of bytes to copy

copy_bytes_back:
        clc
        lda     copy_from_ptr       ; Add copy_length (the length) to copy_from_ptr and copy_to_ptr
        pha                         ; and save the original values on the stack
        adc     copy_length
        sta     copy_from_ptr
        lda     copy_from_ptr+1
        pha
        adc     copy_length+1
        sta     copy_from_ptr+1
        clc
        lda     copy_to_ptr              
        pha                         
        adc     copy_length
        sta     copy_to_ptr
        lda     copy_to_ptr+1
        pha
        adc     copy_length+1
        sta     copy_to_ptr+1

; The stack contains the original copy_from_ptr and copy_to_ptr; we'll use these to move the last bytes.
; The current values of copy_from_ptr and copy_to_ptr are one past the end of the move ranges.
; The number of bytes to move is in copy_length.

        ldy     #0                  ; Y = 0 meaning 256 bytes per block
        ldx     copy_length+1       ; Number of 256-byte blocks
        beq     @remaining          ; If no blocks, just do remaining bytes
@next_block:
        beq     @remaining          ; No more blocks, copy remaining bytes
        dec     copy_from_ptr+1     ; Subtract 256 from copy_from_ptr
        dec     copy_to_ptr+1       ; and copy_to_ptr
        jsr     @copy
        dex                         ; Done with this block
        bne     @next_block         ; More to copy

; Upon reaching this point, both X and Y will be zero.

@remaining:
        pla                         ; Recover original copy_from_ptr and copy_to_ptr from stack
        sta     copy_to_ptr+1
        pla
        sta     copy_to_ptr
        pla
        sta     copy_from_ptr+1
        pla
        sta     copy_from_ptr
        ldy     copy_length         ; Number of bytes left to copy (may be 0)
        beq     @skip_copy          ; No bytes to copy, otherwise fall through to @copy

; Copies bytes from offsets Y-1 to 0. Will copy 256 bytes if Y = 0.
; Y will be 0 on exit.

@copy:
        dey                         ; Decrement Y
        beq     @copy_last_byte     ; Y is 0 but we still have to copy one last byte
        lda     (copy_from_ptr),y   ; Copy one byte
        sta     (copy_to_ptr),y  
        jmp     @copy               ; TODO: optimize for 65C02
@copy_last_byte:
        lda     (copy_from_ptr),y   ; Copy last byte (Y will be 0) (TODO: optimize for 65C02)
        sta     (copy_to_ptr),y
@skip_copy:
        rts

; Signals an error.
; Only used by functions that use err to return error information.
; A = the error code (set to ERR_FAILURE by return_fail)

return_fail:
        lda     #ERR_FAIL
return_error:
        sec
        sta     status
        rts

; Signals that a function completed successfully.
; Only used by functions that use err to signal status.
; A = the status code (set to STATUS_OK by return_ok)

return_ok:
        lda     #STATUS_OK
return_status:
        sta     status
        clc
        rts

; Multiplies the value in AX by 10 by shifting left twice, adding original value, shifting left once more.
; AX = the value to multiply by 10
; Returns the product in AX

mul10:

@mul_tmp = regsave

        sta     @mul_tmp            ; Store value in mul_tmp
        stx     @mul_tmp+1
        asl     A                   ; Shift A + mul_tmp+1 left 2
        rol     @mul_tmp+1
        asl     A                   
        rol     @mul_tmp+1
        clc
        adc     @mul_tmp+0          ; Add in original value and save back
        sta     @mul_tmp+0
        txa
        adc     @mul_tmp+1          ; Same thing for high byte
        asl     @mul_tmp+0          ; Shift the value left once more; A is now the high byte
        rol     A
        tax
        lda     @mul_tmp+0
        rts

; Divides the value in AX by 10. Unfortunately we have to do "real" division; there's no clever shortcut.
; AX = the value to divide by 10
; Returns the quotient in AX and the remainder in Y

div10:

@div_tmp = regsave

        sta     @div_tmp            ; Store value in div_tmp
        stx     @div_tmp+1
        ldx     #16                 ; 16 bits
        lda     #0                  ; Initialize remainder to 0
@next_bit:
        asl     @div_tmp            ; Shift dividend left into A
        rol     @div_tmp+1
        rol     A
        cmp     #10                 ; Reached 10 yet?
        bcc     @not_10
        sbc     #10                 ; Subtract 10 from remainder; carry is set
        inc     @div_tmp            ; Set bit in quotient
@not_10:
        dex                         ; One bit down
        bne     @next_bit           ; Some more to go
        tay                         ; Remainder into Y
        lda     @div_tmp            ; Divisor into AX
        ldx     @div_tmp+1
        rts

; JSR to a vector selected from an array of vectors.
; AX = address of the vector array
; Y = the index of the vector

jsr_indexed_vector:

@vectors = ptr2
    
        sta     @vectors
        stx     @vectors+1
        tya
        asl     A                   ; Multiply by 2 since each vector is 2 bytes
        tay
        lda     (@vectors),y
        sta     jmpvec+1
        iny 
        lda     (@vectors),y
        sta     jmpvec+2
        jmp     jmpvec              ; Handler function RTS will return from *this* function
