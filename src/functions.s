; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

fun_abs:
        asl     FP0s                    ; Clear sign bit
        rts

fun_adr:
        ldax    S0
        rts

fun_asc:
        ldy     #0
        lda     (S0),y                  ; Get first character of string
        ldx     #0                      ; Zero-extend to 16 bits
        rts

fun_chr_s:
        pha                             ; Park the character
        lda     #1                      ; Allocate space for a 1-byte string
        jsr     string_alloc
        pla                             ; Pop the character back
        ldy     #1                      ; Write to string position 1
        sta     (string_ptr),y          ; Set the character in the string
        rts

fun_inkey_s:
        jsr     inkey                   ; Plaform-specific implementation
        bcc     fun_chr_s               ; Got a key (A): return it as a 1-character string
        lda     #0                      ; No key: return an empty string
        jmp     string_alloc

fun_fre:
        jsr     compact                 ; GC strings
        sec                             ; Calculate free memory as himem_ptr - free_ptr
        lda     himem_ptr
        sbc     free_ptr
        tay                             ; Park low byte
        lda     himem_ptr+1
        sbc     free_ptr+1
        tax                             ; High byte in X
        tya                             ; Low byte back into A
        rts

fun_right_s:
        jsr     fun_left_right_prep
        sec
        sbc     D                       ; Subtract requested length from string length to get starting position
        bcs     fun_mid_s_finish        ; Unconditional since D <= string length

fun_left_s:
        jsr     fun_left_right_prep
        lda     #0                      ; Starting position
        beq     fun_mid_s_finish        ; Unconditional since A=0

fun_mid_s:
        bmi     fun_mid_out_of_range    ; Don't allow negative length
        sta     D                       ; Save in D
        jsr     pop_int_fp0             ; Pop the starting position
        bmi     fun_mid_out_of_range    ; Don't allow negative starting position
        sec
        sbc     #1                      ; Subtract 1 to make it 0-based; carry is already set
        bmi     fun_mid_out_of_range    ; Fail if that made it negative (i.e., don't allow starting position to be 0)
        pha                             ; Push starting position on stack
        jsr     fun_mid_s_pop_string    ; String length in E and requested length <= string length in D
        pla                             ; Starting position in A
        cmp     E                       ; Compare to string length
        bcc     @less                   ; Starting position < string length; okay
        lda     E                       ; Otherwise replace with string length
@less:
        pha                             ; Push modified starting position while adjusting requested length
        clc
        sbc     E                       ; A (staring position) - E (string length) - 1
        eor     #$FF                    ; E - A = the length of the string available after starting position
        cmp     D                       ; Compare with requested length
        bcs     @ok                     ; Available length >= requested length: ok
        sta     D                       ; Otherwise make requested length = available length
@ok:
        pla                             ; Pop starting position

; Fall through

; When we get here:
; A is the 0-based starting position.
; D is the requested length and is no more than the length of the string less the starting position.
; E is the total string length, which is no longer relevant, so we'll use it for the starting position instead

fun_mid_s_finish:
        sta     E                       ; Starting position in E
        lda     D
        jsr     string_alloc_for_copy
        ldax    S0                      ; Copy source is S0 + E
        clc
        adc     E
        bcc     @skip_src_inx
        inx
@skip_src_inx:
        jmp     copy_y_from

fun_left_right_prep:
        bmi     fun_mid_out_of_range    ; Don't allow negative length
        sta     D                       ; Save in D

; Fall through

; Go get the string, set E to its length, and also return length in A.
; D contains the requested length; limit it to the string length.

fun_mid_s_pop_string:
        jsr     pop_string_s0
        sta     E
        cmp     D                       ; Compare string length to requested length
        bcs     @ok                     ; String length >= requested length; okay
        sta     D                       ; Otherwise overwrite requested length with string length
@ok:
        rts

fun_mid_out_of_range:
        jmp     raise_out_of_range

fun_peek:
        stax    BC                      ; Need it to be a pointer
        ldy     #0                      ; Index 0
        lda     (BC),y                  ; Get the value there
fun_len:
        ldx     #0                      ; Zero-extend to 16 bits; for len we receive the string length in A
        rts

fun_dpeek:
        jsr     fun_peek                ; Leaves pointer in BC and Y=0
        pha
        iny
        lda     (BC),y                  ; Get high byte
        tax
        pla
        rts

fun_sgn:
        lda     FP0e                    ; If exponent is 0 then value is 0; return 0
        beq     fun_sgn_done
        ldpha   FP0s                    ; Return the sign of the original value
        jsr     load_one_fp0            ; Load 1
        plsta   FP0s                    ; Replace the sign of 1 with the sign of the original number
fun_sgn_done:
        rts

fun_sqr:
        lda     FP0e                    ; Check for 0
        beq     fun_sgn_done            ; Return 0
        jsr     flog                    ; Take logarithm
        dec     FP0e                    ; Decrement exponent to divide by 2
        jmp     fexp                    ; Raise again

fun_str_s:
        jsr     fp_to_string
        lda     buffer                  ; The string length
        jsr     string_alloc_for_copy
        ldax    #buffer+1               ; Source
        jmp     copy_y_from

fun_usr:
        phax                            ; Preserve second argument
        jsr     pop_int_fp0             ; Pop the address
        stax    BC                      ; Store it so I can use it as a pointer
        plax                            ; Recover argument
        jmp     (BC)                    ; Jump through vector

fun_val:
        tay
        lda     #0
        sta     buffer,y                ; Null-terminate buffer[len]
        beq     @check_empty            ; Unconditional since A=0
@loop:
        lda     (S0),y
        sta     buffer,y
@check_empty:
        dey
        bpl     @loop
        iny                             ; Y = 0 as starting index for string_to_fp
        ldax    #buffer
        jmp     string_to_fp            ; Parse it
