.include "macros.inc"
.include "basic.inc"

; LET statement:

exec_let:
        jsr     decode_name             ; Sets name_ptr and name_length
        ldax    variable_name_table_ptr
        jsr     find_name               ; Look for a variable with this name
        bcc     @found                  ; Found it
        ldax    #2                      ; Allocate 2 bytes of space for the variable
        jsr     add_variable            ; Add it
        bcs     @error                  ; Unable to add the variable

; At this point record_ptr will be pointing to the variable data.
; Store it in variable_ptr because we might need record_ptr when parsing the right hand value.

@found:
        mvax    record_ptr, variable_ptr
        jsr     evaluate_expression     ; Value is in AX
        ldy     #0                      ; Index variable value with Y
        sta     (variable_ptr),y        ; Low byte
        iny
        txa
        sta     (variable_ptr),y        ; High byte
        clc                             ; Success
@error:
        rts
