; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

; We treat this as zero.
.assert PS_STOPPED = 0, error

; Initializes a new program.
; Clears the program, all variables, and the string heap. Sets the run state to stopped.
; Does not set next_line_ptr since the program is not running.
; Inserts an empty zero-length line -1 into the program space.

initialize_program:
        mvax    #(__MAIN_START__ + __MAIN_SIZE__), himem_ptr
        mvax    #(__BSS_RUN__ + __BSS_SIZE__), program_ptr  ; Set program_ptr to start of program space
        jsr     append_null_line                            ; Build a null line at program_ptr
        mvax    #(__BSS_RUN__ + __BSS_SIZE__ + .sizeof(Line)), variable_name_table_ptr
        mva     #PS_STOPPED, program_state
        
; Fall through to reset_program_state

; Clears the runtime state of the program.
; Clears all variables and the string heap. The run state and next_line_ptr remain unchanged, so this can be called
; while the program is running.
; variable_name_table_ptr = the address of the variable name table
; BC SAFE

reset_program_state:
        ldx     variable_name_table_ptr ; Add 1 to variable_name_table_ptr to get free_ptr
        ldy     variable_name_table_ptr+1
        inx
        stx     free_ptr
        bne     @skip_iny
        iny
@skip_iny:
        sty     free_ptr+1
        lda     #0                      ; Load zero into A
        sta     resume_line_ptr+1       ; Initialize resume_line_ptr high byte to 0 to disable CONT
        tay                             ; Write index is also zero
        sta     (variable_name_table_ptr),y ; Initialize variable name table to 0
        mva     #OP_STACK_SIZE, op_stack_pos    ; Initialize stack positions
        mva     #PRIMARY_STACK_SIZE, stack_pos
        rts

; Sets next_line_ptr to program_ptr. Does not change the run state.
; Returns next_line_ptr in AX.
; BC SAFE, DE SAFE

reset_next_line_ptr:
        ldax    program_ptr
reset_next_line_ptr_2:
        stax    next_line_ptr
        mvy     #.sizeof(Line), next_line_pos
        rts

; Builds a null line at the location passed in AX. The null line has line number -1 and a length of zero.
; The zero length prevents advance_next_line_ptr from advancing past the line.
; This function makes assumptions about these offsets:

.assert Line::next_line_offset = 0, error
.assert Line::number = 1, error

null_line:
        .byte 0                         ; next_line_offset
        .byte $FF, $FF                  ; number

append_null_line:
        stax    dst_ptr
        ldy     #.sizeof(Line)
        ldax    #null_line
        jmp     copy_y_from

; Searches for a line in the program.
; This function needs to be reasonably fast because it will be called every time the program executes GOTO, 
; GOSUB, RESTORE, or any other function that requires a line number.
; AX = the line number
; Carry clear if ok (the line was found), carry set if error (line not found).
; Sets next_line_ptr if the line was found.
; If not found, next_line_ptr is left set to where the line would have been, i.e., pointing
; to the next-higher line.
; BC SAFE, DE SAFE

find_line:
        stax    line_number
find_line_2:
        jsr     reset_next_line_ptr     ; Set next_line_ptr to beginning of program
        jmp     @test_line              ; Skip over first advance_line_ptr call
@next_line:      
        jsr     advance_next_line_ptr   ; Advance to the next line
@test_line:
        ldy     #Line::number+1         ; Index of high byte of line number
        lda     (next_line_ptr),y        
        cmp     line_number+1      
        bcc     @next_line              ; Line number high byte is <target; go to next line
        bne     @not_found              ; Return with carry set
        dey                             ; High byte is equal; decrement Y to get low byte of line number
        lda     (next_line_ptr),y       ; Check the low byte of line number
        cmp     line_number             ; Same logic for low byte
        bcc     @next_line     
        bne     @not_found              ; If not the line then return with carry bit set
        clc                             ; If it was the line then return with carry clear
@not_found:        
        rts     

; Advances next_line_ptr to the next line.
; next_line_ptr = current next line (updated)
; X SAFE, BC SAFE, DE SAFE

advance_next_line_ptr:
        ldy     #Line::next_line_offset
        lda     (next_line_ptr),y       ; Get next line offset into A
        clc
        adc     next_line_ptr           ; Add line length to low byte of next_line_ptr
        sta     next_line_ptr           ; Save back
        bcc     @skip                   ; Don't need to change the high byte
        inc     next_line_ptr+1         ; Increment the high byte
@skip:
        mvy     #.sizeof(Line), next_line_pos
        rts        

; Updates the program based on the information in line_buffer.
; If the line number in line_buffer is in the program, remove it.
; If line_buffer contains a new line, then insert it into the program.

insert_or_update_line:
        ldax    line_buffer+Line::number    ; Load line number into AX
        jsr     find_line               ; Go find it
        bcs     @insert                 ; Not found, just insert the new line

; next_line_ptr points to a line that we have to remove.

        ldy     #Line::next_line_offset
        lda     (next_line_ptr),y       ; Get next line offset into A
        pha                             ; Save the next line offset on the stack; it will be the shrink length
        jsr     advance_next_line_ptr   ; Advance next_line_ptr to next line
        pla                             ; Get the length of the line back off the stack
        ldy     #next_line_ptr          ; Select next_line_ptr as the pointer to move
        jsr     shrink_a

; Insert the new line, if there is one.
; There is a line if next_line_offset is greater than the offset of the data field.
; next_line_ptr points to where this new line should go.

@insert:
        lda     line_buffer+Line::next_line_offset  ; Load length of line which should be <= 255
        tax                             ; Save in X since we'll need it again
        cmp     #.sizeof(Line)          ; Compare next line offset with the offset of the data field
        beq     @finish                 ; If they're the same, line is blank, nothing to insert
        ldphaa  next_line_ptr           ; Push next_line_ptr onto stack so we can get it back later
        txa                             ; Copy line length back into A as the amount to grow
        ldy     #next_line_ptr          ; Select next_line_ptr as the pointer to move
        jsr     grow_a                  ; Create space for the new line
        plstaa  dst_ptr                 ; Restore the previous next_line_ptr into dst_ptr (even if grow failed)
        bcs     @error                  ; Don't copy if grow failed
        ldax    #line_buffer            ; Set up copy source
        ldy     line_buffer+Line::next_line_offset  ; Length of the new line
        jsr     copy_y_from             ; Copy the line into the program

@finish:
        clc
@error:
        rts

; Grows a section of memory by increasing one of the zero-page pointers, and all subsequent pointers up to (but
; not including) himem_ptr, by some amount.
; This creates a new area of uninitialized memory at the pointer's original address, increasing the memory available
; to the section *before* the pointer we moved.
; AX = the amount to add to the pointer (the grow_a entry point sets X to 0)
; Y = the zero-page address of the pointer to increase
; BC SAFE

grow_a:
        ldx     #0                      ; Initialize high byte to 0
grow:
        stax    DE                      ; Store size in DE
        clc                             ; Do 16-bit add of size in AX to free_ptr to see if it grows past himem_ptr
        adc     free_ptr                ; Add low byte
        tax                             ; Low byte into X
        lda     E                       ; Re-load high byte of size from E
        adc     free_ptr+1              ; Add high byte of free_ptr
        bcs     @done                   ; If carry is set after high byte add then address has overflowed
        cmp     himem_ptr+1             ; Test new high byte of free_ptr
        bcc     @continue               ; Less, everything okay, return
        bne     @done                   ; Not equal so greater, return with carry set
        txa                             ; High bytes are equal; compare low bytes
        cmp     himem_ptr
        bcc     @continue               ; Same logic for low byte
        bne     @done
@continue:
        jsr     grow_shrink_common
        jsr     reverse_copy            ; Copy data up to the higher address
        clc                             ; Success
@done:
        rts

; Shrinks memory by decreasing one of the zero-page pointers, and all subsequent pointers up to (but not including)
; himem_ptr, by some amount.
; We don't check if the amount to subtract would cause the pointer to crash into next-lower pointer in memory;
; this is assumed to never happen.
; This decreases the amount of memory available in the section *before* the pointer we moved.
; AX = the amount to subtract from the pointer (the grow_a entry point sets X to 0)
; Y = the zero-page address of the pointer to increase
; BC SAFE

shrink_a:
        ldx     #0
shrink:
        eor     #$FF                    ; Negate AX and store in DE
        sta     D
        txa
        eor     #$FF
        sta     E                       ; DE is now -AX-1; we still have to add 1
        inc     D
        bne     @skip_increment         ; Increment of D didn't roll over, so don't increment E
        inc     E
@skip_increment:
        jsr     grow_shrink_common
        jsr     copy
        clc
        rts

; Adds the value in DE to the pointer identified by Y, and all subsequent pointers up to (but not including)
; himem_ptr, by some amount. Also sets up src_ptr, dst_ptr, and size for copy.
; Used by both grow and shrink.

grow_shrink_common:
        clc                             ; Clear carry to prepare for addition
        lda     0,y                     ; Load the low byte of the pointer to increase
        sta     src_ptr                 ; Store it as source for copy
        adc     D                       ; Increase low byte
        sta     dst_ptr                 ; It's also the destination pointer
        lda     1,y                     ; Do the same thing for the high byte
        sta     src_ptr+1
        adc     E
        sta     dst_ptr+1
        sec                             ; Knowing src_ptr we can calculate number of bytes to move
        lda     free_ptr
        sbc     src_ptr
        pha                             ; Store low byte of size
        lda     free_ptr+1      
        sbc     src_ptr+1      
        pha                             ; High byte of size
@next_ptr:
        clc
        lda     0,y                     ; Do the same thing only without setting src_ptr and dest_ptr
        adc     D
        sta     0,y
        lda     1,y
        adc     E
        sta     1,y
        iny
        iny
        cpy     #himem_ptr              ; Is Y now pointing at himem_ptr?
        bne     @next_ptr               ; Nope, keep going
        plax                            ; Load AX with size to prepare for call to copy
        rts
