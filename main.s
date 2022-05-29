.include "macros.inc"
.include "target.inc"
.include "basic.inc"

.code

ready_message: .byte "READY"
ready_length = * - ready_message

error_message: .byte "ERROR"
error_length = * - error_message

statement_name_table:
        .byte   'L', 'I', 'S', 'T' | NT_END
        .byte   'R', 'U', 'N' | NT_END
        .byte   'P', 'R', 'I', 'N', 'T', NT_1ARG | NT_END
        .byte   'L', 'E', 'T', NT_1ARG, '=', NT_1ARG | NT_END
        .byte   0

statement_signature_table:
        .byte   TYPE_NONE, TYPE_NONE
        .byte   TYPE_NONE, TYPE_NONE
        .byte   TYPE_INT, TYPE_NONE
        .byte   TYPE_VAR, TYPE_INT

statement_exec_vectors:
        .word   exec_list
        .word   exec_run
        .word   exec_print
        .word   exec_let

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

; Invokes a statement handler from a table.
; This function does not return; it jumps to the handler, which will eventually return.
; A = the index of the handler in the table

invoke_statement_handler:
        tay
        ldax    #statement_exec_vectors
        jmp     invoke_indexed_vector

; Executes the program.

exec_run:
        mvaa    value_table_ptr, BC     ; Prepare to clear variable value table
        lda     variable_count          ; Amount to clear is variable_count * 2
        jsr     mul2a
        jsr     clear_memory
        jsr     reset_line_ptr
@next_line:
        jsr     update_line_fields
        lda     line_number+1           ; Load high byte of line number
        bmi     @end                    ; If MSB of line number is set, we're at end of program
        jsr     decode_byte             ; Get statement number
        jsr     invoke_statement_handler
        ; TODO: check for error
        jsr     advance_line_ptr        ; Advance to next line
        jmp     @next_line

@end:
        rts

; Gets the value for an argument and returns it in AX.

get_argument_value:
        jsr     decode_byte             ; Get statement number
        bmi     @variable               ; It's a variable
        jmp     decode_number           ; Decode a number instead

@variable:
        and     #$7F                    ; Clear bit 7
        jsr     mul2a                   ; Multiply by 2
        adc     value_table_ptr         ; Carry is clear; add to the value table offset
        sta     B
        txa
        adc     value_table_ptr+1
        sta     C                       ; Address of variable data is now in BC
        ldy     #1
        lda     (BC),y                  ; High byte of variable value
        tax
        dey
        lda     (BC),y                  ; Low byte of variable data
        rts

exec_print:
        jsr     get_argument_value      ; Returns value to print in AX
        jsr     print_number            ; Print the number
        jsr     newline
        rts

exec_let:
        rts

; Stop-gap function...

print_number:
        mvy     #0, w
        jsr     format_number
        ldax    #buffer
        ldy     w
        jmp     write

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
