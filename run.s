.include "macros.inc"
.include "basic.inc"

; RUN statement:
; Executes the program.

exec_run:
        mvaa    value_table_ptr, dst_ptr    ; Prepare to clear variable value table
        lda     variable_count          ; Amount to clear is variable_count * 2
        jsr     mul2a
        jsr     clear_memory
        jsr     reset_line_ptr
@run_one_line:
        ldy     #Line::number+1         ; Position of line number high byte
        lda     (line_ptr),y            ; Into A
        bmi     @end                    ; If MSB of line number is set, we're at end of program
        mva     #Line::data, lp         ; Initialize read position to start of data
        jsr     decode_byte             ; Get statement number
        jsr     invoke_statement_handler
        ; TODO: check for error
        jsr     advance_line_ptr        ; Advance to next line
        jmp     @run_one_line

@end:
        rts

; Invokes a statement handler from a table.
; This function does not return; it jumps to the handler, which will eventually return.
; A = the index of the handler in the table

invoke_statement_handler:
        tay
        ldax    #statement_exec_vectors
        jmp     invoke_indexed_vector

; Gets the value for an argument and returns it in AX.

get_argument_value:
        jsr     decode_byte             ; Get statement number
        bmi     @variable               ; It's a variable
        jmp     decode_number           ; Decode a number instead

@variable:
        jsr     set_variable_value_ptr  ; Address of variable data in AX
        ldy     #1
        lda     (variable_value_ptr),y  ; High byte of variable value
        tax
        dey
        lda     (variable_value_ptr),y  ; Low byte of variable data
        rts
