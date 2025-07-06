.include "macros.inc"
.include "basic.inc"

ready_message: .byte "READY"
ready_message_length = * - ready_message
error_message: .byte "ERROR"
error_message_length = * - error_message

keyword_run: .byte 'R', 'U', 'N'+$80
keyword_print: .byte 'P', 'R', 'I', 'N', 'T'+$80

main:
        jsr     initialize_target
        jsr     initialize_program
@ready:
        jsr     print_ready
@wait_for_input:
        jsr     readline
        mva     #0, buffer_pos          ; Initialize the read pointer
        jsr     skip_whitespace
        jsr     read_number             ; Leaves line number in AX and Y points to next character in buffer
        bcs     @immediate_mode         ; No line number; execute in immediate mode
        stax    line_buffer+Line::number
        jsr     skip_whitespace         ; Leaves buffer_pos in X
        ldy     #.sizeof(Line)          ; Start writing into line_buffer after the Line header
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
        ldax    #keyword_run
        jsr     parse_keyword           ; Was it "RUN"?
        bcs     @not_run
        jsr     exec_run
        jmp     @ready

@not_run:
        jsr     print_error
        jmp     @wait_for_input

; Executes the program.

exec_run:
        jsr     reset_line_ptr
@next_line:
        ldy     #Line::number+1         ; High byte of line number
        lda     (line_ptr),y
        bmi     @end                    ; If MSB of line number is set, we're at end of program
        ldy     #Line::next_line_offset ; Get next line offset
        lda     (line_ptr),y
        sta     B                       ; Store in B
        ldx     #0                      ; Copy data into offset 0 in buffer
        ldy     #.sizeof(Line)          ; Starting at data offset
@copy_byte:
        lda     (line_ptr),y            ; Load byte
        sta     buffer,x                ; Store into buffer
        inx
        iny
        cpy     B                       ; End of line?
        bne     @copy_byte              ; No, keep copying
        lda     #0
        sta     buffer,x                ; Store 0 at end of line
        sta     buffer_pos              ; Start reading from offset 0
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
        jsr     putch                   ; Print it
        jmp     @print_digit

@done:
        rts

print_ready:
        jsr     newline
        ldax    #ready_message          ; Pass address of message in AX
        ldy     #ready_message_length   ; Message length
        jsr     write
        jmp     newline

; Prints an error message.

print_error:
        ldax    #error_message          ; Pass address of message in AX
        ldy     #error_message_length   ; Message length
        jsr     write
        jmp     newline
