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
; BC SAFE, DE SAFE

copy_y_from:
        stax    src_ptr                 ; AX is src_ptr; dst_ptr must already be set
        tya                             ; Y is size
copy_a:
        ldx     #0
copy:
        stax    size                    ; Length into size
        ldy     #0                      ; Y = 0 meaning 256 bytes per block
        txa                             ; X is number of 256-byte blocks
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
        dec     src_ptr+1               ; Back up address 256 bytes
        dec     dst_ptr+1
        dex                             ; One block down
        bne     @decrement              ; More blocks to copy
        rts

; Clears 1-256 bytes of memory to zero.
; AX = address of memory to clear
; Y = number of bytes (if Y=0, will clear 256 bytes)

clear_memory:
        stax    dst_ptr                 ; Store the address
        lda     #0 
@next:
        dey
        sta     (dst_ptr),y             ; Does not affect Z
        bne     @next
        rts

; Shifts the value in AX left by 1 bit, multiplying it by 2.
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

; Reads a number from the buffer.
; If the first character is not a digit, then return an error. Otherwise, read up to the first non-digit.
; AX = the buffer address (stored in read_ptr)
; Y = the starting offset
; Returns the number in AX and the last read position in Y, carry clear if ok, carry set if error

read_number:
        stax    read_ptr                ; Store read_ptr
        jsr     find_printable_character                        
        sty     B                       ; Store starting position in B so we can read it later
        lda     #0                      ; Intialize the value to 0
        sta     C                       ; Keep the low byte of the result in C
        tax                             ; X is the high byte
        dey                             ; Negate the next instruction
@next_character:
        iny                             ; Increment the read position
        lda     (read_ptr),y
        and     #$7F                    ; Clear EOT bit if set
        jsr     char_to_digit           ; X SAFE function
        bcs     @finish                 ; If there was an error in char_to_digit, stop parsing
        pha                             ; Save the digit on the stack
        lda     C                       ; Load low byte; result is now in AX
        jsr     mul10                   ; Multiply the value by 10 (preserves Y)
        sta     C                       ; High byte back to C
        pla                             ; Get digit back into A
        clc
        adc     C                       ; Add the digit value
        sta     C                       ; Store back in C
        bcc     @check_eot              ; If carry clear then done with this digit
        inx                             ; Otherwise increment high byte
@check_eot:
        lda     (read_ptr),y            ; Reload the original character
        bpl     @next_character         ; If EOT not set then carry on
        iny                             ; Move past the character with the EOT bit set

@finish:
        cpy     B                       ; Did we parse anything?
        beq     @error                  ; Nope
        clc                             ; Clear carry to signal OK
        lda     C                       ; Load low byte of result from C
@error:
        rts

; Formats a number into buffer. Does not perform any error checking. On exit, X points to the next write position
; in buffer (i.e., it is equal to buffer_pos).
; AX = the number to format
; buffer_pos = the position within buffer (updated)
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
        ldx     buffer_pos              ; Load write offset into X
@output_digit:
        pla                             ; Get a digit
        beq     @done                   ; If it's 0 then we're done
        sta     buffer,x                ; Store in line_buffer
        inx                             ; Update write position
        jmp     @output_digit

@done:
        stx     buffer_pos              ; Update X
        rts

; Reads and discards an argument separator.
; Returns with carry set if the separator was found, else clear, and advances Y past the separator if found.

read_argument_separator:
        jsr     find_printable_character
        cmp     #','
        bne     @not_found
        iny                             ; Advance Y past the separator
        rts

@not_found:
        clc                             ; Carry clear signals not found
        rts

; Reads forward and finds the next non-whitespace character.
; read_ptr = the read address
; Y = the starting position
; Returns the next non-whitespace character in A and the position of that character in Y.

continue_find_printable_character:
        iny
find_printable_character:
        lda     (read_ptr),y
        cmp     #' '
        beq     continue_find_printable_character
        rts
