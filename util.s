.include "macros.inc"
.include "basic.inc"

; Copies bytes from a source address to a destination address.
; The source and destination byte ranges must not overlap unless the destination address is lower than the
; source address.
; Alters src_ptr and dst_ptr.
; src_ptr = source
; dst_ptr = destination (must be <=src_ptr)
; size = number of bytes to copy
; Alternate entry points:
; copy_a accepts a size < 256 bytes in A.
; copy_size uses the size already stored in size.
; BC SAFE, DE SAFE

copy_a:
        ldx     #0
copy:
        stax    size                    ; Length into size
copy_size:
        ldy     #0                      ; Y = 0 meaning 256 bytes per block
        ldx     size+1                  ; Number of 256-byte blocks
        beq     @remaining              ; If no blocks, just do remaining bytes
@next_byte: 
        lda     (src_ptr),y             ; Copy one byte
        sta     (dst_ptr),y                
        iny                             ; Next byte
        bne     @next_byte              ; More to move
        inc     src_ptr+1               ; Add 256
        inc     dst_ptr+1               ; to both src_ptr and dst_ptr
        dex                             ; Decrement number of blocks
        bne     @next_byte              ; More to move

; Copies the remaining bytes.
; Y must be 0 when we first reach this point, and size must be set to the number of bytes remaining (0 means none).

@remaining:
        ldx     size
        beq     @done                   ; If equal then we're done
@next_remaining_byte:
        lda     (src_ptr),y             ; Otherwise move one more byte
        sta     (dst_ptr),y    
        iny
        dex
        bne     @next_remaining_byte
@done:
        rts

; Copy bytes backwards from a source address to a destination address.
; Used when the source and destination byte ranges overlap and destination address is higher than the source address.
; Alters src_ptr and dst_ptr.
; src_ptr = source
; dst_ptr = destination (must be <=src_ptr)
; size = number of bytes to copy
; Alternate entry points:
; reverse_copy_size uses the size already stored in size.
; BC SAFE, DE SAFE

reverse_copy:
        stax    size                    ; Length into size
reverse_copy_size:
        ldx     size+1                  ; Number of 256-byte blocks we will move
        txa                             ; Move src_ptr and dst_ptr up the remainder block
        clc
        adc     src_ptr+1
        sta     src_ptr+1
        txa
        clc
        adc     dst_ptr+1
        sta     dst_ptr+1
        inx                             ; X is number of blocks including partial block
        ldy     size                    ; The size of the partial block
        beq     @next_block
        bne     @decrement
@next_byte:
        lda     (src_ptr),y             ; Copy one byte
        sta     (dst_ptr),y
@decrement:
        dey
        bne     @next_byte
        lda     (src_ptr),y             ; Handle Y=0
        sta     (dst_ptr),y
@next_block:
        dec     src_ptr+1               ; Back up address 256 bytes
        dec     dst_ptr+1
        dex                             ; One block down
        bne     @decrement              ; More blocks to copy
        rts

; Invokes a vector selected from an table of vectors.
; JSR to here to have the routine at the vector return to the caller of this function, or JMP to have it
; return to the caller's caller.
; Callers can use BC and DE to pass parameters to the target function.
; Since Y, the vector index, can never exceed 127, the ASL will clear the carry flag, and it will still be clear
; when control reaches the target routine.
; AX = address of the vector table
; Y = the index of the vector
; BC SAFE, DE SAFE

invoke_indexed_vector:
        stax    vector_table_ptr
        tya
        asl     A                       ; Multiply by 2 since each vector is 2 bytes
        tay
        iny                             ; Increment by 1 to get the high byte first
        lda     (vector_table_ptr),y
        pha
        dey                             ; Move to low byte
        lda     (vector_table_ptr),y    
        pha
        rts                             ; RTS jumps to vector pushed on the stack

; Advance lp by the number of bytes in A.

advance_lp_sizeof_float:
        lda     #.sizeof(Float)
advance_lp:
        clc
        adc     lp
        sta     lp
        rts                             ; Carry should be set on return since we can't overflow line_buffer
