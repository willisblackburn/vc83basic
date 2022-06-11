.include "macros.inc"
.include "basic.inc"

.zeropage

; Additional general-purpose "registers." Register rules apply; don't expect them to be preserved unless a
; function declares B SAFE etc. Can be used as the 16-bit pairs BC and DE. Don't alias these.

BC:
B: .res 1
C: .res 1
DE:
D: .res 1
E: .res 1

; Contains the error code when a function returns with the carry set
; to signal an error. May also be used to pass information about the outcome of a function,
; for example if a function completed successfully (carry clear) but had no effect.
status: .res 1

src_ptr: .res 2
dst_ptr: .res 2

.code

; Copies bytes from a source address to a destination address.
; The source and destination byte ranges must not overlap unless the destination address is lower than the
; source address.
; Alters src_ptr and dst_ptr.
; src_ptr = source
; dst_ptr = destination (must be <=src_ptr)
; AX = number of bytes to copy (_de entry point uses value in DE instead)

copy_bytes:
        stax    DE                      ; Length into DE
copy_bytes_de:
        ldy     #0                      ; Y = 0 meaning 256 bytes per block
        ldx     E                       ; Number of 256-byte blocks
        beq     @remaining              ; If no blocks, just do remaining bytes
@next_byte: 
        lda     (src_ptr),y             ; Copy one byte
        sta     (dst_ptr),y                
        iny                             ; Next byte
        bne     @next_byte              ; More to move
        inc     src_ptr+1               ; Add 256
        inc     dst_ptr+1               ; to both src_ptr and dst_ptr
        dex                             ; Decrement number of blocks
        bne     @next_byte              ; Move to move

; Copy the remaining bytes.
; Y = 0 when we first reach this point

@remaining:
        cpy     D                       ; Compare Y with number of remaining bytes
        beq     @return                 ; If equal then we're done
        lda     (src_ptr),y             ; Otherwise move one more byte
        sta     (dst_ptr),y               
        iny 
        jmp     @remaining

@return:
        rts

; Copy bytes backwards from a source address to a destination address.
; Used when the source and destination byte ranges overlap and destination address is higher than the source address.
; Alters src_ptr and dst_ptr.
; src_ptr = source
; dst_ptr = destination (must be <=src_ptr)
; AX = number of bytes to copy (_de entry point uses value in DE instead)

copy_bytes_back:
        stax    DE                      ; Length into DE
copy_bytes_back_de:
        clc
        lda     src_ptr                 ; Add DE (the length) to src_ptr and dst_ptr
        pha                             ; and save the original values on the stack
        adc     D
        sta     src_ptr
        lda     src_ptr+1
        pha
        adc     E
        sta     src_ptr+1
        clc
        lda     dst_ptr              
        pha                         
        adc     D
        sta     dst_ptr
        lda     dst_ptr+1
        pha
        adc     E
        sta     dst_ptr+1

; The stack contains the original src_ptr and dst_ptr; we'll use these to move the last bytes.
; The current values of src_ptr and dst_ptr are one past the end of the move ranges.
; The number of bytes to move is in DE.

        ldy     #0                      ; Y = 0 meaning 256 bytes per block
        ldx     E                       ; Number of 256-byte blocks
        beq     @remaining              ; If no blocks, just do remaining bytes
@next_block:    
        beq     @remaining              ; No more blocks, copy remaining bytes
        dec     src_ptr+1               ; Subtract 256 from src_ptr
        dec     dst_ptr+1               ; and dst_ptr
        jsr     @copy   
        dex                             ; Done with this block
        bne     @next_block             ; More to copy

; Upon reaching this point, both X and Y will be zero.

@remaining:
        pla                             ; Recover original src_ptr and dst_ptr from stack
        sta     dst_ptr+1
        pla
        sta     dst_ptr
        pla
        sta     src_ptr+1
        pla
        sta     src_ptr
        ldy     D                       ; Number of bytes left to copy (may be 0)
        beq     @skip_copy              ; No bytes to copy, otherwise fall through to @copy

; Copies bytes from offsets Y-1 to 0. Will copy 256 bytes if Y = 0.
; Y will be 0 on exit.

@copy:
        dey                             ; Decrement Y
        beq     @copy_last_byte         ; Y is 0 but we still have to copy one last byte
        lda     (src_ptr),y             ; Copy one byte
        sta     (dst_ptr),y     
        jmp     @copy                   
@copy_last_byte:    
        lda     (src_ptr),y             ; Copy last byte (Y will be 0)
        sta     (dst_ptr),y
@skip_copy:
        rts

; Clears memory to zero.
; dst_ptr = pointer to the memory to clear
; AX = the number of bytes to clear (_de entry point uses value in DE instead)

clear_memory:
        stax    DE                      ; Number of bytes in DE
clear_memory_de:
        lda     #0                      ; Zero byte to write
        tax                             ; X is the number of blocks written; initialize to 0
        tay                             ; Y is the number of bytes written; initialize to 0
@do_block:
        cpx     E                       ; More blocks to copy?
        beq     @do_remaining_byte      ; No more blocks; go copy remaining bytes
@block_byte:
        sta     (dst_ptr),y             ; Write one zero
        iny                             ; Y is the number of bytes written; when it wraps to 0 means 256 bytes
        bne     @block_byte             ; Not rolled over yet
        inc     dst_ptr+1               ; Advance write address in BC to next block
        inx                             ; Increment number of blocks written
        jmp     @do_block

@do_remaining_byte:
        cpy     D                       ; More?
        beq     @done                   ; Nope
        sta     (dst_ptr),y             ; Write remaining byte
        iny                             ; Y is the number of bytes written so will not be zero, ...
        bne     @do_remaining_byte      ; therefore this is an unconditional branch

@done:
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

; Shifts the value in AX left by 1 bit, multiplying it by 2.
; Y SAFE

mul2a:
        ldx     #0                      ; Only multiply A by initializing high byte to 0     
mul2:
        stx     E                       ; Park high byte in E so we can roll into it
        asl     A                       ; Low byte * 2
        rol     E                       ; High byte * 2
        ldx     E                       ; Reload X
        rts

; Multiplies the value in AX by 10 by shifting left twice, adding original value, shifting left once more.
; AX = the value to multiply by 10
; Returns the product in AX
; Y SAFE, BC SAFE

mul10:
        stax    DE
        asl     A                       ; Shift A + E left 2
        rol     E
        asl     A
        rol     E
        clc                             ; Clear carry to prepare for addition
        adc     D                       ; Add in original low byte in D and save back
        sta     D  
        txa                             ; Same thing for high byte
        adc     E                      
        asl     D                       ; Shift the value left once more; A is now the high byte
        rol     A
        tax                             ; Move high byte back into X
        lda     D                       ; Reload low byte from D back into A
        rts

; Divides the value in AX by 10. Unfortunately we have to do "real" division; there's no clever shortcut.
; AX = the value to divide by 10
; Returns the quotient in AX and the remainder in Y
; BC SAFE

div10:
        stax    DE
        ldx     #16                     ; 16 bits
        lda     #0                      ; Initialize remainder to 0
@next_bit:  
        asl     D                       ; Shift dividend left into A
        rol     E  
        rol     A   
        cmp     #10                     ; Reached 10 yet?
        bcc     @not_10 
        sbc     #10                     ; Subtract 10 from remainder; carry is set
        inc     D                       ; Set bit in quotient
@not_10:    
        dex                             ; One bit down
        bne     @next_bit               ; Some more to go
        tay                             ; Remainder into Y
        ldax    DE
        rts

; Invokes a vector selected from an array of vectors.
; JSR to here to have the routine at the vector return to the caller of this function, or JMP to have it
; return to the caller's caller.
; AX = address of the vector array
; Y = the index of the vector

invoke_indexed_vector:
        stax    BC
        tya
        asl     A                       ; Multiply by 2 since each vector is 2 bytes
        tay
        lda     (BC),y                  ; Load low byte of vector
        sta     D                       ; Set up DE as the jump vector                
        iny     
        lda     (BC),y    
        sta     E
        jmp     (DE)                    ; Handler function RTS will return from *this* function

; Formats a number into buffer. Does not perform any error checking. On exit, X points to the next write position
; in buffer (i.e., it is equal to w).
; AX = the number to format
; w = the position within buffer (updated)

format_number:
        sta     B                       ; Keep low byte in B while we use A for other things
        lda     #0                      ; Push 0 on the stack
        pha
@next_digit:
        lda     B                       ; Recover low byte
        jsr     div10                   ; Divide AX by 10
        sta     B                       ; Save low byte
        tya                             ; Transfer remainder into A
        clc
        adc     #'0'
        pha                             ; Push digit
        txa                             ; High byte into A
        ora     B                       ; OR with saved low byte
        bne     @next_digit             ; Still more digits
        ldx     w                       ; Load write offset into X
@output_digit:
        pla                             ; Get a digit
        beq     @done                   ; If it's 0 then we're done
        sta     buffer,x                ; Store in line_buffer
        inx                             ; Update write position
        jmp     @output_digit

@done:
        stx     w                       ; Update X
        rts

; Writes a single byte to buffer at position w and increments w.
; Does not check for buffer overflow; we assume this can't happen.
; A = the byte to write
; w = the buffer position (updated)
; Y SAFE

putchar_space_buffer:
        lda     #' '
putchar_buffer:
        ldx     w                       ; Load position
        inc     w                       ; Incrment position
        sta     buffer,x                ; Store A in buffer
        rts
