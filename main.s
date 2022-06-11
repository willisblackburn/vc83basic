.include "macros.inc"
.include "basic.inc"

ready_message: .byte "READY"
ready_length = * - ready_message

error_message: .byte "ERROR"
error_length = * - error_message

main:
        jsr     initialize_target
        jsr     initialize_program
@ready:
        jsr     print_ready
@wait_for_input:
        jsr     readline
        lda     #0                      ; Initialize read and write pointers
        sta     r
        sta     w
        jsr     skip_whitespace
        jsr     read_number             ; Leaves line number in AX and Y points to next character in buffer
        bcs     @immediate_mode         ; No line number; execute in immediate mode
        stax    parsed_line_number
        jsr     @get_statement
        bcs     @error
        ldax    parsed_line_number
        jsr     find_line
        bcs     @insert                 ; Line not found, just insert the new one
        jsr     delete_line             ; Delete the existing line
@insert:
        ldax    parsed_line_number
        jsr     insert_line             ; Insert the new line
        jmp     @wait_for_input

@immediate_mode:
        ldx     r                       ; Check the current read position
        lda     buffer,x                ; Anything on the line?
        beq     @wait_for_input         ; It's a blank line, wait for another one
        jsr     @get_statement
        bcs     @error
        lda     line_buffer             ; Statement is in first byte of line_buffer
        jsr     invoke_statement_handler
        jmp     @wait_for_input

@get_statement:
        jsr     skip_whitespace
        mvax    #statement_signature_table, signature_ptr
        ldax    #statement_name_table
        jsr     parse_element           ; Leaves the parsed statement in line_buffer
        rts

@error:
        jsr     print_error
        jmp     @wait_for_input

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
