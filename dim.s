.include "macros.inc"
.include "basic.inc"

; DIM statement:

exec_dim:
        jsr     decode_name             ; Get the name and type
        sec                             ; Set carry in case this next check fails
        lda     decode_name_arity       ; See if it's an array name
        bpl     @invalid_variable       ; Nope
        jsr     evaluate_argument_list  ; Evaluate the dimensions values (A = decdee_name_arity = $FF)
        inc     line_pos                ; Skip ')'
        eor     #$FF                    ; Invert to get number of arguments
        sta     decode_name_arity
        ldax    array_name_table_ptr    ; Look for the name in the name table
        jsr     find_name
        bcc     @already_dimensioned
        jmp     dimension_array         ; Go do it

@invalid_variable:
        raise   ERR_INVALID_VARIABLE

@already_dimensioned:
        raise   ERR_ALREADY_DIMENSIONED