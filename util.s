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

copy_y_from:
        stax    src_ptr                 ; AX is src_ptr; dst_ptr must already be set
        tya                             ; Y is size
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
        cpy     size                    ; More?
        beq     @done                   ; Nope
        lda     (src_ptr),y             ; Otherwise move one more byte
        sta     (dst_ptr),y    
        iny                             ; Y is the number of bytes written so will not be zero, ...
        bne     @remaining              ; therefore this is an unconditional branch

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

; Clears memory to zero.
; dst_ptr = pointer to the memory to clear
; AX = the number of bytes to clear (_size entry point uses value in size instead)
; On return the byte count will remain in size.
; BC SAFE, DE SAFE

clear_memory:
        stax    size                    ; Number of bytes in size
clear_memory_size:
        lda     #0                      ; Zero byte to write
        tax                             ; X is the number of blocks written; initialize to 0
        tay                             ; Y is the number of bytes written; initialize to 0
@next_block:
        cpx     size+1                  ; More blocks to clear?
        beq     @remaining              ; No more blocks; go clear remaining bytes
@block_byte:
        sta     (dst_ptr),y             ; Write one zero
        iny                             ; Y is the number of bytes written; when it wraps to 0 means 256 bytes
        bne     @block_byte             ; Not rolled over yet
        inc     dst_ptr+1               ; Advance write address in BC to next block
        inx                             ; Increment number of blocks written
        bne     @next_block             ; X will never be zero, so this is is unconditional

@remaining:
        cpy     size                    ; More?
        beq     @done                   ; Nope
        sta     (dst_ptr),y             ; Write remaining byte
        iny                             ; Y is the number of bytes written so will not be zero, ...
        bne     @remaining              ; therefore this is an unconditional branch

@done:
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

; Advance line_pos by the number of bytes in A.

advance_lp_sizeof_float:
        lda     #.sizeof(Float)
advance_lp:
        clc
        adc     line_pos
        sta     line_pos
        rts                             ; Carry should be clear on return since we can't overflow line_buffer

; Allocates space 

node_alloc:

