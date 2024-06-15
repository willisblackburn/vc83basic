.include "macros.inc"
.include "basic.inc"

; Gets the value for an expression and returns it in AX.

evaluate_expression:
        ldy     line_pos
        lda     (line_ptr),y            ; Peek at the next byte
        cmp     #TOKEN_NUM
        bne     @variable               ; It's a variable
        jsr     decode_number           ; Decode a number instead
        clc
        rts

@variable:
        jsr     decode_variable
        ldax    variable_name_table_ptr
        jsr     find_name               ; Look for a variable with this name
        bcc     @found                  ; Found it
        ldax    #2                      ; Allocate 2 bytes of space for the variable
        jsr     add_variable            ; Add it
        bcs     @fail                   ; Unable to add the variable
@found:
        ldy     #1                      ; Start with high byte of value
        lda     (record_ptr),y
        tax
        dey
        lda     (record_ptr),y
        clc                             ; Success
@fail:
        rts
