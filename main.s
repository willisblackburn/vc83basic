.include "macros.inc"
.include "basic.inc"

ready_message: .byte "READY"
ready_length = * - ready_message

error_message: .byte "ERROR"
error_length = * - error_message

keyword_list: .byte 'L', 'I', 'S', 'T'+$80
keyword_run: .byte 'R', 'U', 'N'+$80
keyword_print: .byte 'P', 'R', 'I', 'N', 'T'+$80

main:
        jsr     initialize_target
        jsr     initialize_program
@ready:
        jsr     print_ready
@wait_for_input:
        jsr     readline
        mva     #0, r                   ; Initialize the read pointer
        jsr     skip_whitespace
        jsr     read_number             ; Leaves line number in AX and Y points to next character in buffer
        bcs     @immediate_mode         ; No line number; execute in immediate mode
        stax    line_buffer+Line::number
        jsr     skip_whitespace
        ldx     r                       ; Read position in to X
        ldy     #Line::data             ; Start writing into line_buffer at the position of the line_data field
@copy_one_char:        
        lda     buffer,x                ; Load next char from buffer
        beq     @copy_done              ; Finished loading into line buffer
        sta     line_buffer,y           ; Store character in y line buffer
        inx
        iny
        jmp     @copy_one_char

@copy_done:
        sty     line_buffer+Line::next_line_offset  ; Store Y, which is the line length, into next_line_offset
        jsr     insert_or_update_line   ; Update the program
        jmp     @wait_for_input

@immediate_mode:
        ldax    #keyword_list
        jsr     parse_keyword           ; Was it "LIST"?
        bcs     @not_list
        jsr     exec_list
        jmp     @ready

@not_list:
        ldax    #keyword_run
        jsr     parse_keyword           ; Was it "RUN"?
        bcs     @not_run
        jsr     exec_run
        jmp     @ready

@not_run:
        jsr     print_error
        jmp     @wait_for_input

; Scans through the program and prints each line.

exec_list:
        jsr     reset_line_ptr
@next_line:
        ldy     #Line::number+1         ; High byte of line number
        lda     (line_ptr),y
        bmi     @end                    ; If MSB of line number is set, we're at end of program
        tax
        dey                             ; Index of line number low byte
        lda     (line_ptr),y            ; Low byte of line number
        jsr     print_number
        lda     #' '
        jsr     putchar
        ldy     #Line::next_line_offset ; Line length
        lda     (line_ptr),y
        sec
        sbc     #Line::data             ; Subtract the size of the header
        tay
        lda     #Line::data
        jsr     add_line_ptr_offset     ; Puts pointer to start of line data in AX
        jsr     write
        jsr     newline
        jsr     advance_line_ptr
        jmp     @next_line

@end:
        rts

; Executes the program.

exec_run:
        jsr     reset_line_ptr
@next_line:
        ldy     #Line::number+1         ; High byte of line number
        lda     (line_ptr),y
        bmi     @end                    ; If MSB of line number is set, we're at end of program
        lda     #Line::data
        jsr     add_line_ptr_offset     ; Puts pointer to start of line data in AX
        stax    src_ptr                 ; Copy from there
        mvaa    #buffer, dst_ptr        ; Into buffer
        ldy     #Line::next_line_offset ; Offset of line length
        lda     (line_ptr),y            ; Get next line offset
        sec
        sbc     #Line::data             ; Subtract the offset of the data field
        ldx     #0                      ; High byte of the length is 0
        jsr     copy_bytes              ; Copy the line data into buffer
        mva     #0, r                   ; Start reading from offset 0
        ldax    #keyword_print          ; Check if the keyword is print
        jsr     parse_keyword           ; Was it "PRINT"?
        bcs     @error                  ; Nope
        jsr     skip_whitespace
        jsr     read_number             ; Get the number
        bcs     @error                  ; Fail if not a number
        jsr     print_number            ; Print the number
        jsr     newline
        jsr     advance_line_ptr
        jmp     @next_line

@error:
        jsr     print_error
@end:
        rts

; Prints the number in AX to the console.

print_number:
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
@print_digit:
        pla                             ; Get a digit
        beq     @done                   ; If it's 0 then we're done
        jsr     putchar                 ; Print it
        jmp     @print_digit

@done:
        rts

print_ready:
        ldax    #ready_message          ; Pass address of message in AX
        ldy     #ready_length
        jsr     write
        jmp     newline

; Prints an error message.

print_error:
        ldax    #error_message          ; Pass address of message in AX
        ldy     #error_length
        jsr     write
        jmp     newline
