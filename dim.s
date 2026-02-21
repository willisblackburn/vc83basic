
; DIM statement:

exec_dim:
        jsr     decode_name             ; Get the name and type
        sec                             ; Set carry in case this next check fails
        lda     decode_name_arity       ; See if it's an array name
        bpl     @error                  ; Nope
        jsr     evaluate_argument_list  ; Evaluate the dimensions values (A = decdee_name_arity = $FF)
        bcs     @error
        eor     #$FF                    ; Invert to get number of arguments
        sta     decode_name_arity
        ldax    array_name_table_ptr    ; Look for the name in the name table
        jsr     find_name
        ldax    name_ptr
        bcc     @error                  ; Name already exists
        jmp     dimension_array         ; Go do it

@error:
        sec                             ; Have to set carry because if name exists we get here with carry clear
        rts
