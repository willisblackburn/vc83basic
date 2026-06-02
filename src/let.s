; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

; LET statement:

exec_let:
        jsr     decode_name             ; Sets decode_name_ptr and decode_name_length
        jsr     find_or_add_variable
        inc     line_pos                ; Skip terminator
        ldphaa  name_ptr                ; Remember name_ptr 
        jsr     evaluate_expression     ; Value is now on the evaluation stack
        plstaa  name_ptr                ; Restore name so we can assign it

; Fall through

; Pops a value from the stack and copies it into the variable identified by name_ptr.
; name_ptr = pointer to the variable's data in the variable name table

assign_variable:
        lda     decode_name_type        ; Determine what format the allocated memory natively represents
        jsr     stack_free_value_with_type      ; Drop the actively evaluated item from the top of the stack and yield X representing its base boundary
        
        ldy     decode_name_type        ; Restore the target variable type index
        lda     type_size_table,y       ; Fetch structural footprint directly mapping index (5 for numeric, 2 for string offset)
        sta     B                       ; Save loop delimiter threshold inside B locally
        ldy     #0                      ; Init sequence relative iteration pointer to exactly 0 to offset naturally up
@copy_loop:
        lda     stack,x                 ; Pull byte directly mapping baseline evaluation layer
        sta     (name_ptr),y            ; Bind into memory aligned table space
        inx                             ; Traverse source footprint
        iny                             ; Traverse destination footprint
        cpy     B                       ; Evaluate alignment matching our explicitly retained structural delimiter
        bne     @copy_loop
        
        clc                             ; Explicitly clear carry flag natively assuming success 
        rts
