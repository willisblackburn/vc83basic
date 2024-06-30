.include "macros.inc"
.include "basic.inc"

; LET statement:

exec_let:
        jsr     decode_variable         ; Read the variable; sets name_ptr and name_length
        jsr     find_or_initialize_variable
        bcs     @error

; At this point record_ptr will be pointing to the variable data.
; Store it in variable_ptr because we might need record_ptr when parsing the right hand value.

        mvax    record_ptr, variable_ptr
        jsr     evaluate_expression     ; Value is in AX
        jmp     assign_variable

@error:
        rts

; Finds a variable, or adds it.
; name_ptr = pointer to the variable name
; name_length = the length of the variable
; Returns carry clear if find_name or add_variable succeeded, or carry set on error.

find_or_initialize_variable:
        ldax    variable_name_table_ptr
        jsr     find_name               ; Look for a variable with this name
        bcs     @not_found              ; Most common case is that it's found, so branch only if it's not
        rts                             ; Return success

@not_found:
        ldax    #2                      ; Allocate 2 bytes of space for the variable
        jmp     add_variable            ; Add it

; Assigns the value in AX to the variable identified by variable_ptr.
; AX = the variable value
; variable_ptr = pointer to the variable's data in the variable name table

assign_variable:
        ldy     #0                      ; Index variable value with Y
        sta     (variable_ptr),y        ; Low byte
        iny
        txa
        sta     (variable_ptr),y        ; High byte
        clc                             ; Success
        rts
