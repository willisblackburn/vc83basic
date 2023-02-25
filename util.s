.include "macros.inc"
.include "basic.inc"

.zeropage

; Additional general-purpose "registers." Register rules apply; don't expect them to be preserved unless a
; function declares B SAFE etc. Can be used as the 16-bit pairs BC and DE. Don't alias these.

BCDE:
BC:
B: .res 1
C: .res 1
DE:
D: .res 1
E: .res 1

; Source and destination pointers for memory opreations
src_ptr: .res 2
dst_ptr: .res 2

; Pointer to the table of vectors used by invoke_indexed_vector
vector_table_ptr: .res 2

.code

; Copies bytes from a source address to a destination address.
; The source and destination byte ranges must not overlap unless the destination address is lower than the
; source address.
; Alters src_ptr and dst_ptr.
; src_ptr = source
; dst_ptr = destination (must be <=src_ptr)
; AX = number of bytes to copy (_de entry point uses value in DE instead)
; Alternate entry points for when there are fewer than 255 bytes to copy:
; copy_bytes_y accepts the destination pointer in AX and the length in Y.
; copy_bytes_a uses the existing dst_ptr and accepts the length in A.
; BC SAFE

copy_bytes_y:
        stax    dst_ptr
        tya
copy_bytes_a:
        ldx     #0
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

; Copies the remaining bytes.
; Y must be 0 when we first reach this point, and D must be set to the number of bytes remaining (0 means none).

@remaining:
        cpy     D                       ; Compare Y with number of remaining bytes
        beq     @done                   ; If equal then we're done
        lda     (src_ptr),y             ; Otherwise move one more byte
        sta     (dst_ptr),y               
        iny 
        bne     @remaining              ; Y will never increment to 0 so this is unconditional

@done:
        rts

; Copy bytes backwards from a source address to a destination address.
; Used when the source and destination byte ranges overlap and destination address is higher than the source address.
; Alters src_ptr and dst_ptr.
; src_ptr = source
; dst_ptr = destination (must be <=src_ptr)
; AX = number of bytes to copy (_de entry point uses value in DE instead)
; BC SAFE

copy_bytes_higher:
        stax    DE                      ; Length into DE
copy_bytes_higher_de:
        clc
        ldpha   src_ptr                 ; Add DE (the length) to src_ptr and dst_ptr; save originals on stack
        adc     D
        sta     src_ptr
        ldpha   src_ptr+1
        adc     E
        sta     src_ptr+1
        clc
        ldpha   dst_ptr              
        adc     D
        sta     dst_ptr
        ldpha   dst_ptr+1
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
        plsta   dst_ptr+1               ; Recover original src_ptr and dst_ptr from stack
        plsta   dst_ptr
        plsta   src_ptr+1
        plsta   src_ptr
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

; Shifts the value in AX left by 3 bits, multiplying it by 3.
; Y SAFE, BC SAFE

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

; Invokes a vector selected from an table of vectors.
; JSR to here to have the routine at the vector return to the caller of this function, or JMP to have it
; return to the caller's caller.
; Callers can use BC to pass parameters to the target function.
; Since Y, the vector index, can never exceed 127, the ASL will clear the carry flag, and it will still be clear
; when control reaches the target routine.
; AX = address of the vector table
; Y = the index of the vector
; BC SAFE

invoke_indexed_vector:
        stax    vector_table_ptr
        tya
        asl     A                       ; Multiply by 2 since each vector is 2 bytes
        tay
        lda     (vector_table_ptr),y    ; Load low byte of vector
        sta     D                       ; Set up BC as the jump vector                
        iny     
        lda     (vector_table_ptr),y    
        sta     E
        jmp     (DE)                    ; Handler function RTS will return from *this* function

; Formats a number into buffer. Does not perform any error checking. On exit, X points to the next write position
; in buffer (i.e., it is equal to bp).
; AX = the number to format
; bp = the position within buffer (updated)
; TODO: replace this with call to fp_to_string

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
        ldx     bp                      ; Load write offset into X
@output_digit:
        pla                             ; Get a digit
        beq     @done                   ; If it's 0 then we're done
        sta     buffer,x                ; Store in line_buffer
        inx                             ; Update write position
        jmp     @output_digit

@done:
        stx     bp                      ; Update X
        rts
