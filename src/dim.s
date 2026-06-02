; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

; DIM statement:

exec_dim:
        jsr     decode_name             ; Get the name and type
        lda     decode_name_arity       ; See if it's an array name
        bpl     @invalid_variable       ; Nope
        jsr     evaluate_argument_list  ; Evaluate the dimensions values (A = decdee_name_arity = $FF)
        inc     line_pos                ; Skip ')'
        eor     #$FF                    ; Invert to get number of arguments
        sta     decode_name_arity
        ldax    array_name_table_ptr    ; Look for the name in the name table
        jsr     find_name
        bcc     @already_dimensioned
        jsr     dimension_array         ; Go do it
        jsr     peek_byte               ; Check for comma (more arrays)
        cmp     #','
        bne     @done                   ; No more arrays
        inc     line_pos                ; Skip ','
        bne     exec_dim                ; Unconditional: loop for next array

@done:
        rts

@invalid_variable:
        jmp     raise_invalid_variable

@already_dimensioned:
        raise   ERR_ALREADY_DIMENSIONED