; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

; Software implementation of a random number generator.
; Separated out from the rest of functions so we can replace it on a machine that includes a hardware random
; number generator.

rnd_mask:       .byte $B7, $1D, $C1, $04

; Generates a new random value in rnd_value.
; Uses a 32-bit linear feedback shift register (LFSR) with taps defined by rnd_mask.
; To generate one random bit, we shift rnd_value left one bit and then, if the bit we shifted into the carry is 1, we
; XOR the seed with the rnd_mask. The random bit is the bit we shifted off the left, but we don't use it, because in
; fact the value left in rnd_value contains the *last* value returned from the RND function. We we generate 32 new
; bits and then just return them directly from rnd_value. The value of rnd_mask is the CRC32 polynomial and will
; generate random numbers with a cycle of 2^31-1.

rnd_generate:
        ldy     #32                     ; Each iteration generates 1 pseudo-random bit
@next_shift:
        asl     rnd_value
        rol     rnd_value+1
        rol     rnd_value+2
        rol     rnd_value+3
        bcc     @skip_feedback
        ldx     #4
@next_feedback:
        lda     rnd_mask-1,x
        eor     rnd_value-1,x
        sta     rnd_value-1,x
        dex
        bne     @next_feedback
@skip_feedback:
        dey
        bne     @next_shift
        rts

rnd_reseed:
        ldx     #4                      ; Copy given number into rnd_value
@next_copy_to_value:
        lda     FP0t-1,x
        sta     rnd_value-1,x
        dex
        bne     @next_copy_to_value
        rts        
