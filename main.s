; cc65 runtime
.include "zeropage.inc"

.include "target.inc"
.include "basic.inc"

ready_message: .byte "READY"
ready_length = * - ready_message

error_message: .byte "ERROR"
error_length = * - error_message

statement_name_table:
        .byte   'L', 'I', 'S', 'T', NT_2ARG | NT_END
        .byte   'R', 'U', 'N', NT_1ARG | NT_END
        .byte   'P', 'R', 'I', 'N', 'T', NT_2ARG | NT_END
        .byte   0

statement_signature_table:
        .byte   TYPE_INT | TYPE_OPTIONAL, TYPE_INT | TYPE_OPTIONAL
        .byte   TYPE_INT | TYPE_OPTIONAL, TYPE_NONE
        .byte   TYPE_CH | TYPE_OPTIONAL, TYPE_PRINT

statement_exec_vectors:
        .word   exec_list
        .word   exec_run
        .word   exec_print

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
        lda     #<statement_name_table
        ldx     #>statement_name_table
        jsr     find_name
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
        lda     statement_exec_vectors,x
        sta     ptr1
        lda     statement_exec_vectors+1,x
        sta     ptr1+1
        jmp     (ptr1)                  ; Jump to handler; handle will RTS to caller

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
        jsr     find_name
        bcs     @error
        jsr     invoke_statement_handler
        jsr     advance_line_ptr
        jmp     @next_line

@error:
        jsr     print_error
@end:
        rts

exec_print:
        jsr     read_number             ; Get the number
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
