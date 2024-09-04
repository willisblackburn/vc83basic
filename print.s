.include "macros.inc"
.include "basic.inc"

; PRINT statement:

.assert TOKEN_NO_VALUE = 0, error
.assert TYPE_NUM = 0, error

exec_print_number:
        jsr     pop_fp0                 ; Get the value
        jsr     print_number            ; Print the number
exec_print:
        ldy     line_pos                ; Read line_pos into Y
        lda     (line_ptr),y            ; Peek at next character
        beq     @end_line               ; Found TOKEN_NO_VALUE
@continue:
        cmp     #TOKEN_EMPTY_SPACE
        beq     @empty_space
        cmp     #TOKEN_TAB
        beq     @tab
        jsr     evaluate_expression     ; Leaves value on stack
        bcs     @done
        ldx     psp                     ; Get the current stack pointer
        lda     primary_stack+Value::type,x     ; Get the type of the variable
        beq     exec_print_number
        jsr     pop_string
        jsr     print_string
        jmp     exec_print

@end_line:
        jmp     print_newline

@tab:
        lda     #' '
        jsr     putch
        inc     print_column
        lda     print_column
        and     #$0F                    ; Is column evenly divisible by 16?
        bne     @tab                    ; Not yet
@empty_space:
        inc     line_pos                ; Skip over the empty space or tab token
        ldy     line_pos
        lda     (line_ptr),y            ; Peek at next character
        bne     @continue               ; It's not the end of the PRINT so continue
        clc
@done:
        rts                             ; Otherwise return without printing a carriage return

; Prints the value in FP0 to standard output.

print_number:
        mva     #1, buffer_pos                  ; Start printing at buffer column 1
        jsr     fp_to_string            ; Format into buffer
        ldx     buffer_pos              ; Load length (including the length byte)
        dex                             ; Length is one less than buffer_pos
        stx     buffer                  ; Store the length in the first character of buffer; it is now a string
        ldax    #buffer                 ; Load the address in AX and fall through to print_string

; Prints the string pointed to by AX to the standard output.
; DE SAFE

print_string:
        jsr     load_s0                 ; Get string address and length
        tay                             ; Transfer length into Y for write
        clc
        adc     print_column            ; Increase print_column by the size of the printed string
        sta     print_column
        ldax    S0                      ; Load string address into AX
        jmp     write
        
print_newline:
        jsr     newline
        mva     #0, print_column
        clc
        rts
