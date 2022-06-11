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
        lda     #0                      ; Initialize the read pointer
        sta     r
        jsr     read_number             ; Leaves line number in AX and Y points to next character in buffer
        bcs     @immediate_mode         ; Wasn't a number, maybe an immediate mode command
        pha                             ; Save line number
        txa
        pha
        jsr     skip_whitespace
        pla
        tax
        pla
        jsr     insert_or_update_line   ; Delete an existing line, if it exists
        jmp     @wait_for_input

@immediate_mode:
        lda     #<keyword_list
        ldx     #>keyword_list
        jsr     parse_keyword           ; Was it "LIST"?
        bcs     @not_list
        jsr     exec_list
        jmp     @ready

@not_list:
        lda     #<keyword_run
        ldx     #>keyword_run
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
        ldy     #1                      ; High byte of line number
        lda     (line_ptr),y
        bmi     @end                    ; If MSB of line number is set, we're at end of program
        tax
        dey
        lda     (line_ptr),y            ; Low byte of line number
        jsr     print_number
        lda     #' '
        jsr     putchar
        ldy     #2                      ; Line length
        lda     (line_ptr),y
        tay
        jsr     get_line_start          ; Puts pointer to start of line data in AX
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
        ldy     #1                      ; High byte of line number
        lda     (line_ptr),y
        bmi     @end                    ; If MSB of line number is set, we're at end of program
        ldy     #2                      ; Offset of line length
        lda     (line_ptr),y            ; Get length
        sta     copy_length             ; and copy_length
        lda     #0
        sta     copy_length+1
        jsr     get_line_start          ; Start of line in AX
        sta     copy_from_ptr           ; Set source for copy
        stx     copy_from_ptr+1
        lda     #<buffer                ; Set destination for copy
        sta     copy_to_ptr
        lda     #>buffer
        sta     copy_to_ptr+1
        jsr     copy_bytes              ; Copy line into buffer
        lda     #0                      ; Start reading from offset 0
        sta     r
        lda     #<keyword_print         ; Check if the keyword is print
        ldx     #>keyword_print
        jsr     parse_keyword           ; Was it "PRINT"?
        bcs     @error                  ; Nope
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

@save_a = tmp1

        sta     @save_a                 ; Keep low byte in @save_a while we use A for other things
        lda     #0                      ; Push 0 on the stack
        pha
@next_digit:
        lda     @save_a                 ; Recover low byte
        jsr     div10                   ; Divide AX by 10
        sta     @save_a                 ; Save low byte
        tya                             ; Transfer remainder into A
        clc
        adc     #'0'
        pha                             ; Push digit
        txa                             ; High byte into A
        ora     @save_a                 ; OR with saved low byte
        bne     @next_digit             ; Still more digits
@print_digit:
        pla                             ; Get a digit
        beq     @done                   ; If it's 0 then we're done
        jsr     putchar                 ; Print it
        jmp     @print_digit

@done:
        rts

print_ready:
        lda     #<ready_message         ; Pass address of message in AX
        ldx     #>ready_message
        ldy     #ready_length
        jsr     write
        jmp     newline

; Prints an error message.

print_error:
        lda     #<error_message         ; Pass address of message in AX
        ldx     #>error_message
        ldy     #error_length
        jsr     write
        jmp     newline
