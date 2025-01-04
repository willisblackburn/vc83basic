.include "macros.inc"
.include "basic.inc"

; DIM statement:

.assert TYPE_ARRAY = $80, error

exec_dim:
        jsr     decode_name             ; Get the name and type
        clc
        lda     decode_name_type        ; See if it's an array name
        bpl     @done                   ; Nope; nothing to do

; Calculate space required for this array.

        and     #$7F                    ; Clear the array bit
        tax                             ; Transfer into X
        lda     type_size_table,x       ; In order to look up the size for this type
        ldx     #0                      ; AX is the 16-bit size
        jsr     int_to_fp               ; Load as float into FP0
        jsr     push_fp0                ; Push onto the stack
        bcs     @done                   ; Out of space
@next:
        jsr     decode_expression       ; Decode the next expression; the value is now on the stack
        jsr     push_value_1            ; We have to add one to the value
        jsr     op_add
        jsr     op_mul                  ; Multiply the two stack values together
        ldy     line_pos
        lda     (line_ptr),y            ; Peek at next character
        bne     @next                   ; Keep decoding more dimensions
        jsr     truncate_fp_to_int
        stax    BC                      ; Store the returned size in BC
        ora     C                       ; OR the two values together to check for zero
        
        
        
        




@done:
        rts
