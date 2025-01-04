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
        bcs     @error                  ; Out of space
@next:
        jsr     evaluate_expression     ; Evaluate the next expression; the value is now on the stack
        bcs     @error
        jsr     push_value_1            ; We have to add one to the value
        bcs     @error
        jsr     op_add
        jsr     op_mul                  ; Multiply the two stack values together
        ldy     line_pos
        lda     (line_ptr),y            ; Peek at next character
        bne     @next                   ; Keep decoding more dimensions
        jsr     truncate_fp_to_int
        debug $00
        bcs     @error                  ; Value was too large
        bmi     @error                  ; Value was negative
        jsr
        

        
        
        
        




@done:
        rts
