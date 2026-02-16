.include "macros.inc"
.include "basic.inc"

; POKE

exec_poke:
        jsr     evaluate_argument_list
        jsr     pop_fp0                 ; Pop the value
        jsr     truncate_fp_to_int      ; Convert into an integer
        pha                             ; Push the low byte; high byte doesn't matter
        jsr     pop_fp0                 ; Pop the address
        jsr     truncate_fp_to_int      ; Convert into an integer
        stax    BC                      ; Park it
        ldy     #0                      ; Prepare to store
        pla                             ; Recover the value
        sta     (BC),y                  ; Store it
        rts
