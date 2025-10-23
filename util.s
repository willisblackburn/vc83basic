.include "macros.inc"
.include "basic.inc"

; Copies bytes from a source address to a destination address.
; The source and destination byte ranges must not overlap unless the destination address is lower than the
; source address.
; On exit, src_ptr and dst_ptr will both have increased by size.
; src_ptr = source
; dst_ptr = destination (must be <=src_ptr)
; size = number of bytes to copy
; Alternate entry points:
; copy_a accepts a size < 256 bytes in A.
; BC SAFE, DE SAFE

copy_y_from:
        stax    src_ptr                 ; AX is src_ptr; dst_ptr must already be set
        tya                             ; Y is size
copy_a:
        ldx     #0
copy:
        stax    size                    ; Length into size; X will be the number of 256-byte blocks to copy
        ora     size+1                  ; Check for size = 0
        beq     @done                   ; Just skip everything
        lda     #0                      ; Low byte of #256
        sec
        sbc     size                    ; Subtract size from 256; this is initial Y value for short block
        tay                             ; Into Y
        beq     @next_byte              ; Even number of blocks; skip all the short block stuff
        clc                             ; Add size % 256 to source_ptr
        lda     src_ptr
        adc     size
        sta     src_ptr
        bcs     @src_has_carry          ; Need to add 1 to src_ptr high byte; can just skip decrement instead
        dec     src_ptr+1
@src_has_carry:
        clc                             ; Add size % 256 to dst_ptr
        lda     dst_ptr
        adc     size
        sta     dst_ptr
        bcs     @dst_has_carry
        dec     dst_ptr+1
@dst_has_carry:
        inx                             ; Add 1 to number of blocks to account for short block

; Once we get here, X is >0, and either:
; There are X 256-byte blocks to copy, and Y is 0.
; There are X-1 256-byte blocks to copy, plus one short block, and Y is (256 - size of short block).

@next_byte: 
        lda     (src_ptr),y             ; Copy one byte
        sta     (dst_ptr),y                
        iny                             ; Next byte
        bne     @next_byte              ; More to move
        inc     src_ptr+1               ; Add 256
        inc     dst_ptr+1               ; to both src_ptr and dst_ptr
        dex                             ; Decrement number of blocks
        bne     @next_byte              ; More to move

@done:
        rts

; Copy bytes backwards from a source address to a destination address.
; Used when the source and destination byte ranges overlap and destination address is higher than the source address.
; Returns src_ptr and dst_ptr set to their original values, so can also be used for non-overlapping copies, when we
; want to retain the src_ptr and dst_ptr values.
; src_ptr = source
; dst_ptr = destination (must be <=src_ptr if overlapping)
; size = number of bytes to copy
; Alternate entry points:
; BC SAFE, DE SAFE

reverse_copy:
        stax    size                    ; Length into size
        txa                             ; X is the number of 256-byte blocks to move;
        clc                             ; Move src_ptr and dst_ptr up to the remainder block
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
        dex                             ; Any more blocks?
        beq     @done                   ; Nope
        dec     src_ptr+1               ; Back up address 256 bytes
        dec     dst_ptr+1
        bne     @decrement              ; Unconditional since we'll never copy into zero page
@done:
        rts

; Clears 1-256 bytes of memory to zero.
; AX = address of memory to clear
; Y = number of bytes (if Y=0, will clear 256 bytes)
; The set_memory entry point just writes whatever is in A to 1-256 bytes starting at dst_ptr.

clear_memory:
        stax    dst_ptr                 ; Store the address
        lda     #0 
set_memory:
        dey
        sta     (dst_ptr),y             ; Does not affect Z
        bne     set_memory
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

; Reads a comma beween arguments. Also recognizes 0 as end of input.
; read_ptr = the read address
; Y = the starting position
; Returns carry clear if everything was okay or carry set if we found something other than a comma or 0.

read_argument_separator:
        jsr     find_printable_character
        clc                             ; Set carry in case next check is okay
        beq     @done                   ; Read 0; just exit
        cmp     #','                    ; If it wasn't 0 then it better be ','
        sec                             ; Set carry in case it's not ','
        bne     @done                   ; And it's not
        clc                             ; Clear carry to return success
        iny                             ; Skip past the commma
@done:
        sty     data_line_pos           ; Update data_line_pos to next read position
        rts

; Reads forward and finds the next non-whitespace character, which might be 0.
; read_ptr = the read address
; Y = the starting position
; Returns the next non-whitespace character in A and the position of that character in Y. If Z is set on return,
; it means the character read was 0.

continue_find_printable_character:
        iny
find_printable_character:
        lda     (read_ptr),y
        beq     @done
        cmp     #' '
        beq     continue_find_printable_character
@done:
        rts

; Installs an exception handler.
; The exception handler itself is the code after the call to this function. Whenever the program performs
; "raise n" (or loads n into A and jumps to on_raise), this function will appear to return with that value in A.
; The caller can check if it is handling an exception, or just returning from the initial call, by checking the carry.
; If carry is clear, then it is the initial call, and if set, then handling an exception.
; The caller should not return while there is still a chance that the program will jump to on_raise, in order to avoid
; its being re-entered from on_raise with the stack in an unknown state. 
; BC SAFE, DE SAFE

install_exception_handler:
        tay                             ; Remember the value of A; will be restored before returning
        plstaa  exception_handler       ; Remember return address of this function as the exception handler
        tsx
        stx     exception_handler_sp    ; Remember the stack pointer after popping the address
        clc                             ; Clear carry to signal we're returning from original call
        bcc     on_raise_2              ; Unconditional; execute on_raise code but with carry clear

on_raise:
        sec                             ; Signal this was caused by raise invocation
        tay                             ; Save the exception value
on_raise_2:
        ldx     exception_handler_sp    ; Restore the stack pointer that we saved in install_exception_handler
        txs
        ldphaa  exception_handler       ; Restore the return address
        tya                             ; Return the exception number in A
        rts
