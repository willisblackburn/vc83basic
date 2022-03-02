; cc65 runtime
.include "zeropage.inc"

.include "basic.inc"

ready_message: .byte "READY"
ready_length = * - ready_message

error_message: .byte "ERROR"
error_length = * - error_message

statement_name_table:
        .byte 'L', 'I', 'S', 'T'+$80
        .byte 'R', 'U', 'N'+$80
        .byte 'P', 'R', 'I', 'N', 'T'+$80

statement_handlers:
        .word list
        .word run
        .word print

main:
        jsr     initialize_target
        jsr     initialize_program
@ready:
        jsr     print_ready
@wait_for_input:
        jsr     readline
        lda     #0                      ; Initialize the read pointer
        sta     r
        jsr     parse_number            ; Leaves line number in AX and Y points to next character in buffer
        bcs     @immediate_mode         ; Wasn't a number, maybe an immediate mode command
        pha                             ; Save line number
        jsr     skip_whitespace
        pla
        jsr     insert_or_update_line   ; Delete an existing line, if it exists
        jmp     @wait_for_input

@immediate_mode:
        lda     #<statement_name_table
        ldx     #>statement_name_table
        jsr     parse_name
        bcs     @error
        jsr     invoke_statement_handler
        jmp     @wait_for_input

@error:
        jsr     print_error
        jmp     @wait_for_input

; Invokes a statement handler from a table.
; This function does not return; it jumps to the handler, which will eventually return.
; A = the index of the handler in the table

invoke_statement_handler:
        asl     A                       ; Multiply index by 2
        tax                             ; Use to look up handler and copy into ptr1
        lda     statement_handlers,x
        sta     ptr1
        lda     statement_handlers+1,x
        sta     ptr1+1
        jmp     (ptr1)                  ; Jump to handler; handle will RTS to caller

; Scans through the program and prints each line.

list:
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

run:
        jsr     reset_line_ptr
@next_line:
        ldy     #1                      ; High byte of line number
        lda     (line_ptr),y
        bmi     @end                    ; If MSB of line number is set, we're at end of program
        ldy     #2                      ; Offset of line length
        lda     (line_ptr),y            ; Get length
        sta     buffer_length           ; Store in buffer_length
        sta     sreg                    ; and sreg
        lda     #0
        sta     sreg+1
        jsr     get_line_start          ; Start of line in AX
        sta     ptr1                    ; Set source for copy
        stx     ptr1+1
        lda     #<buffer                ; Set destination for copy
        sta     ptr2
        lda     #>buffer
        sta     ptr2+1
        jsr     copy_bytes              ; Copy line into buffer
        lda     #0                      ; Start reading from offset 0
        sta     r
        lda     #<statement_name_table    ; What statement was it?
        ldx     #>statement_name_table
        jsr     parse_name
        bcs     @error
        jsr     invoke_statement_handler
        jsr     advance_line_ptr
        jmp     @next_line

@error:
        jsr     print_error
@end:
        rts

print:
        jsr     parse_number            ; Get the number
        bcs     @error                  ; Fail if not a number
        jsr     print_number            ; Print the number
        jsr     newline
        rts

@error:
        jsr     print_error
@end:
        rts

; Prints the number in AX to the console.

print_number:
        sta     tmp1                    ; Start with high byte in tmp1
        lda     #0                      ; Push 0 on the stack
        pha
@next_digit:
        lda     tmp1                    ; Recover low byte from tmp1
        jsr     div10                   ; Divide AX by 10
        sta     tmp1                    ; Save low byte in tmp1
        tya                             ; Transfer remainder into A
        clc
        adc     #'0'
        pha                             ; Push digit
        txa                             ; High byte into A
        ora     tmp1                    ; OR with low byte
        bne     @next_digit             ; Still more to digits
@print_digit:
        pla                             ; Get a digit
        beq     @done                   ; If it's 0 then we're done
        jsr     putchar                 ; Print it
        jmp     @print_digit

@done:
        rts

print_ready:
        lda     #<ready_message         ; Pass address of message in ptr1
        ldx     #>ready_message
        ldy     #ready_length
        jsr     write
        jsr     newline
        rts

; Prints an error message.

print_error:
        lda     #<error_message         ; Pass address of message in ptr1
        ldx     #>error_message
        ldy     #error_length
        jsr     write
        jsr     newline
        rts
