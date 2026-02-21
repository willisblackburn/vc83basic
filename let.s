
; LET statement:

exec_let:
        jsr     decode_name             ; Sets decode_name_ptr and decode_name_length
        inc     line_pos                ; Skip terminator
        jsr     find_or_add_variable
        ldphaa  name_ptr                ; Remember name_ptr
        jsr     evaluate_expression     ; Value is in AX
        tay                             ; Hold low byte of result while we recover name_ptr
        plstaa  name_ptr                ; Recover name_ptr
        tya                             ; Restore low byte of result
        jmp     assign_variable

@error:
        rts

; Assigns the value in AX to the variable identified by name_ptr.
; AX = the variable value
; name_ptr = pointer to the variable's data in the variable name table

assign_variable:
        ldy     #0                      ; Index variable value with Y
        sta     (name_ptr),y            ; Low byte
        iny
        txa
        sta     (name_ptr),y            ; High byte
        clc                             ; Success
@error:
        rts
