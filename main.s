.include "macros.inc"
.include "basic.inc"

ready_message: .byte "READY"
ready_length = * - ready_message

error_message: .byte "ERROR"
error_length = * - error_message

; TODO: Create parse_line to prepare line_buffer; make skip_whitespace private to parser.s

main:
        jsr     initialize_target
        jsr     initialize_program
@ready:
        jsr     print_ready
@wait_for_input:
        jsr     readline
        mva     #0, r                   ; Initialize the read pointer
        mva     #Line::data, w          ; Initialize write pointer
        jsr     read_number             ; Leaves line number in AX and Y points to next character in buffer
        bcs     @immediate_mode         ; No line number; execute in immediate mode
        stax    line_buffer+Line::number
        jsr     @get_statement
        bcs     @error
        mva     w, line_buffer+Line::next_line_offset   ; Write position is next statement offset
        jsr     insert_or_update_line   ; Update the program
        jmp     @wait_for_input

@immediate_mode:
        ldx     r                       ; Check the current read position
        lda     buffer,x                ; Anything on the line?
        beq     @wait_for_input         ; It's a blank line, wait for another one
        jsr     @get_statement
        bcs     @error
        lda     line_buffer+Line::data  ; Statement is in line_buffer.data
        jsr     invoke_statement_handler
        jmp     @wait_for_input

@get_statement:
        ldax    #statement_name_table
        jsr     parse_element           ; Leaves the parsed statement in line_buffer
        rts

@error:
        jsr     print_error
        jmp     @wait_for_input

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
