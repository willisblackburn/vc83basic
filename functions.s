.include "macros.inc"
.include "basic.inc"

fun_len:
        jsr     pop_string
        jsr     load_s0                 ; Length comes back in A, which is what we want
        ldx     #0                      ; High byte is always 0
        jsr     int_to_fp               ; Into FP0
        jmp     push_fp0                ; Push return value

fun_str_s:
        jsr     pop_fp0
        mva     #1, buffer_pos          ; Write at buffer position 1
        jsr     fp_to_string
        ldy     buffer_pos              ; Save the length byte at offset 0
        dey                             ; Don't include the length byte
        sty     buffer
        tya
        jsr     string_alloc            ; Allocate space for the string
        bcs     @done                   ; No space left
        ldy     buffer_pos              ; Already includes the length byte
        mvax    string_ptr, dst_ptr     ; Set up copy destination
        ldax    #buffer                 ; Source
        jsr     copy_y_from
        ldax    string_ptr
        jmp     push_string

@done:
        rts

