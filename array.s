.include "macros.inc"
.include "basic.inc"

; DIM statement:

.assert TYPE_ARRAY = $80, error

exec_dim:
        jsr     decode_name             ; Get the name and type
        clc
        lda     decode_name_type        ; See if it's an array name
        bpl     @done                   ; Nope; nothing to do

@done:
        rts
