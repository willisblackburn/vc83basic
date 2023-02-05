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
; BC SAFE

copy_bytes_a:
        ldx     #0                      ; Default high byte to 0
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

copy_bytes_higher_a:
        ldx     #0                      ; Default high byte to 0
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

; Clears memory to zero.
; dst_ptr = pointer to the memory to clear
; AX = the number of bytes to clear (_de entry point uses value in DE instead)
; On return the byte count will remain in DE.
; BC SAFE

clear_memory_a:
        ldx     #0
clear_memory:
        stax    DE                      ; Number of bytes in DE
clear_memory_de:
        ldax dst_ptr
        lda     #0                      ; Zero byte to write
        tax                             ; X is the number of blocks written; initialize to 0
        tay                             ; Y is the number of bytes written; initialize to 0
@next_block:
        cpx     E                       ; More blocks to clear?
        beq     @remaining_byte         ; No more blocks; go clear remaining bytes
@block_byte:
        sta     (dst_ptr),y             ; Write one zero
        iny                             ; Y is the number of bytes written; when it wraps to 0 means 256 bytes
        bne     @block_byte             ; Not rolled over yet
        inc     dst_ptr+1               ; Advance write address in BC to next block
        inx                             ; Increment number of blocks written
        bne     @next_block             ; X will never be zero, so this is is unconditional

@remaining_byte:
        cpy     D                       ; More?
        beq     @done                   ; Nope
        sta     (dst_ptr),y             ; Write remaining byte
        iny                             ; Y is the number of bytes written so will not be zero, ...
        bne     @remaining_byte         ; therefore this is an unconditional branch

@done:
        rts

; Shifts the value in AX left by 3 bits, multiplying it by 3.
; Y SAFE, BC SAFE

mul8a:
        ldx     #0                      ; Only multiply A by initializing high byte to 0     
mul8:
        stx     E                       ; Park high byte in E so we can roll into it
        asl     A                       ; Shift AE left 3 bits to multiply by 8
        rol     E
        asl     A
        rol     E
        asl     A
        rol     E
        ldx     E                       ; Reload X
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

; Advance lp by the number of bytes in A.

advance_lp_sizeof_float:
        lda     #.sizeof(Float)
advance_lp:
        clc
        adc     lp
        sta     lp
        rts                             ; Carry should be set on return since we can't overflow line_buffer
