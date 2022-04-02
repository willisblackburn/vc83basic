; cc65 runtime
.include "zeropage.inc"

.import __BSS_RUN__, __BSS_SIZE__

.include "target.inc"
.include "basic.inc"

.zeropage

; A pointer to the current program line
line_ptr: .res 2

; The length of the current line
line_length: .res 1
; The curent line number; also used to store line number sought in find_line
line_number: .res 2

.bss

; A pointer to the start of the program
program_ptr: .res 2

; The start of the variable name table
variable_name_table_ptr: .res 2

; The start of the heap
heap_ptr: .res 2

.code

; Initializes a new program.
; Inserts an empty zero-length line -1 into the program space.

initialize_program:
        clc
        lda     #<__BSS_RUN__       ; Set program_ptr and line_ptr to end of BSS
        adc     #<__BSS_SIZE__
        sta     program_ptr
        sta     line_ptr
        lda     #>__BSS_RUN__  
        adc     #>__BSS_SIZE__
        sta     program_ptr+1
        sta     line_ptr+1
        lda     #$FF                ; Line number = -1
        ldy     #0                  
        sta     (line_ptr),y        ; Line number low byte
        iny
        sta     (line_ptr),y        ; Line number high byte
        lda     #0
        iny
        sta     (line_ptr),y        ; Line length
        jsr     get_line_start_plus_a   ; Adding header + A (0) to line_start gives variable_name_table_ptr in AX
        sta     variable_name_table_ptr
        stx     variable_name_table_ptr+1
        sta     heap_ptr            ; Nothing in the variable name table so heap_ptr is same
        stx     heap_ptr+1
        rts

; Sets line_ptr to program.
; X SAFE, Y SAFE

reset_line_ptr:
        lda     program_ptr
        sta     line_ptr
        lda     program_ptr+1
        sta     line_ptr+1
        rts

; Searches for a line in the program.
; This function needs to be reasonably fast because it will be called every time
; the program executes GOTO, GOSUB, RESTORE, or any other function that requires
; a line number.
; The find_line_number entry point uses the line number in line_number.
; Sets line_ptr, line_number, and line_length if the line was found.
; If not found, line_ptr is left set to where the line would have been, i.e., pointing
; to the next-higher line.
; AX = the line number
; Carry clear if ok (the was found), carry set if error (line not found).

find_line:
        sta     line_number         ; Stash the line number
        stx     line_number+1
find_line_number:
        jsr     reset_line_ptr      ; Set line_ptr to beginning of program
next_line:
        ldy     #1                  ; Set Y to 1 for getting high byte of line number
        lda     (line_ptr),y
        cmp     line_number+1
        bcc     @continue           ; Line number high byte is <target; go to next line
        bne     @return             ; Return with carry set
        dey                         ; High byte is equal; decrement Y to 0
        lda     (line_ptr),y        ; Check the low byte of line number
        cmp     line_number         ; Same logic for low byte
        bcc     @continue
        bne     @return             ; Return with carry set
        iny                         ; Y = 1
        iny                         ; Y = 2 to get the length byte
        lda     (line_ptr),y        ; Line length
        sta     line_length         ; Save it
        clc                         ; Signal ok
@return:
        rts

@continue:
        jsr     advance_line_ptr    ; Advance to the next line    
        jmp     next_line

; Advances the current line pointer to the next line.
; Operates directly on line_ptr.
; Returns line line_ptr value in AX.

advance_line_ptr:
        ldy     #2                  ; Need offset 2 to get length
        lda     (line_ptr),y        ; Get length of current line
        jsr     get_line_start_plus_a
        sta     line_ptr            ; Store back into line_ptr
        stx     line_ptr+1          
        rts

; Returns a pointer to the start of data for the current line (identified by line_ptr).
; The get_line_ptr_plus_a entry point adds whatever is in A to line_ptr.
; The get_line_start_plus_a entry point adds the size of the line header.
; Returns the pointer in AX.
; Y SAFE

get_line_start:
        lda     #0                  ; Add 0 extra bytes after header
get_line_start_plus_a:
        clc
        adc     #3                  ; Add 3 bytes for header
get_line_ptr_plus_a:
        clc
        adc     line_ptr            ; Add whatever's in A to line_ptr
        ldx     line_ptr+1
        bcc     @return
        inx
@return:
        rts

; Inserts or updates a program line.
; buffer = the line data
; buffer_length = the buffer length
; AX = the line number
; r = a pointer to the read offset in buffer 
; Returns carry clear if okay, carry set if error (e.g., out of memory).

insert_or_update_line:
        jsr     find_line           ; Saves line number in line_number
        bcs     @insert             ; Not found, just insert the new line

; line_ptr points to a line that we have to remove.
; Find the next line and copy the reset of the program to where line_ptr is pointing now.
; There will always be a next line becasue we'll only be here if the line to delete
; actually exists.

        lda     line_ptr            ; Current line_ptr
        sta     copy_to_ptr         ; will be the target of the memcpy
        pha                         ; Also push it on the stack so we can restore after advancing
        lda     line_ptr+1          ; High byte
        sta     copy_to_ptr+1
        pha
        jsr     advance_line_ptr    ; Move to line_ptr to next line (AX = line_ptr)
        sta     copy_from_ptr       ; This will be the source for the copy
        stx     copy_from_ptr+1
        jsr     calculate_bytes_to_move ; Set copy_length to length of program from line_ptr
        jsr     update_pointers     ; Knowing copy from and to, we can update pointers
        jsr     copy_bytes          ; Compact the program
        pla                         ; line_ptr now points to an invalid line so restore saved value
        sta     line_ptr+1
        pla
        sta     line_ptr

; Insert the new line, if there is one.
; There is a line if Y (recovered from tmp1) is less than buffer_length.
; line_ptr points to where this new line should go.

@insert:
        lda     line_ptr            ; Initialize copy_from_ptr to line_ptr
        ldx     line_ptr+1          ; This will be the source for the copy
        sta     copy_from_ptr                
        stx     copy_from_ptr+1
        lda     buffer_length       ; Load buffer_length, which should be <= 252
        sec
        sbc     r                   ; Subtract the buffer index to get line length
        beq     @finish             ; If they're the same, line is blank, nothing to insert
        pha                         ; Save the line length on the stack
        jsr     get_line_start_plus_a   ; Allocate space for new line plus header
        sta     copy_to_ptr                
        stx     copy_to_ptr+1
        jsr     calculate_bytes_to_move ; Set copy_length to length of program from line_ptr
        jsr     update_pointers     ; Knowing copy from and to, we can update pointers
        jsr     copy_bytes_back
        lda     line_number
        ldy     #0
        sta     (line_ptr),y        ; Save line item number low byte
        lda     line_number+1
        iny
        sta     (line_ptr),y        ; Save line item number high byte
        pla                         ; Get the line length saved earlier
        iny
        sta     (line_ptr),y        ; Save line length
        sta     copy_length         ; Also save it into copy_length
        lda     #0
        sta     copy_length+1       ; Set high byte of copy_length to 0
        clc
        lda     #<buffer            ; Buffer start address
        adc     r                   ; Add buffer index
        sta     copy_from_ptr       ; Set source address
        lda     #>buffer            ; Do the same for the high byte (TODO: if buffer is fixed address we can remove)
        adc     #0                  ; This will leave carry clear
        sta     copy_from_ptr+1
        jsr     get_line_start      ; Get destination address for copy
        sta     copy_to_ptr         ; Destination into copy_to_ptr
        stx     copy_to_ptr+1
        jsr     copy_bytes          ; Copy data from buffer into program space
        jsr     calculate_bytes_to_move ; Reset copy_length
        jsr     advance_line_ptr    ; Jump over the new line

@finish:
        clc
        rts

; Calculates the bytes to move for both compact and expand as heap_ptr - line_ptr.
; Returns the number of bytes in copy_length (borrowed from util.s)

calculate_bytes_to_move:
        sec                       
        lda     heap_ptr
        sbc     line_ptr
        sta     copy_length         ; Store length
        lda     heap_ptr+1
        sbc     line_ptr+1
        sta     copy_length+1       ; Store high byte of length
        rts

; Updates variable_name_table_ptr and heap_ptr by adding (copy_to_ptr - copy_from_ptr).
; In other words, if we're moving everything to a higher address (copy_to_ptr > copy_from_ptr), then we have
; to move the pointers up too, and vice versa. We're just shifting the pointers by however many bytes
; we moved the end of the program.
; Uses XY to store the difference value.

update_pointers:
        sec           
        lda     copy_to_ptr
        sbc     copy_from_ptr
        tax                         ; Difference low byte in X
        lda     copy_to_ptr+1
        sbc     copy_from_ptr+1
        tay                         ; Difference high byte in Y
        clc                         ; Update variable_name_table_ptr
        txa                      
        adc     variable_name_table_ptr
        sta     variable_name_table_ptr
        tya
        adc     variable_name_table_ptr+1
        sta     variable_name_table_ptr+1
        clc                         ; Update heap_ptr
        txa                      
        adc     heap_ptr
        sta     heap_ptr
        tya
        adc     heap_ptr+1
        sta     heap_ptr+1
        rts
