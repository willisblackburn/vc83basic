.include "macros.inc"
.include "basic.inc"

fun_abs:
        jsr     pop_fp0
        mva     #0, FP0s                ; Set sign to positive unconditionally
        jmp     push_fp0

fun_adr:
        jsr     pop_string_s0
        ldax    S0
        jmp     push_int_fp0

fun_asc:
        jsr     pop_string_s0
        ldy     #0
        lda     (S0),y                  ; Get first character of string
        ldx     #0
        jmp     push_int_fp0            ; Push it

fun_chr_s:
        jsr     pop_int_fp0
        pha                             ; Park the character
        lda     #1                      ; Allocate space for a 1-byte string
        jsr     string_alloc
        pla                             ; Pop the character back
        ldy     #1                      ; Write to string position 1
        sta     (string_ptr),y          ; Set the character in the string
        jmp     push_string

fun_fre:
        jsr     compact                 ; GC strings
        sec                             ; Calculate free memory
        lda     himem_ptr
        sbc     free_ptr
        tay                             ; Park low byte
        lda     himem_ptr+1
        sbc     free_ptr+1
        tax                             ; High byte in X
        tya                             ; Low byte back into A
        jmp     push_int_fp0

fun_int:
        jsr     pop_fp0
        jsr     truncate
        jmp     push_fp0        

fun_left_s:
        jsr     fun_mid_s_setup         ; Requested length in D
        jsr     fun_mid_s_pop_string    ; String length in E and requested length <= string length in D
        lda     #0                      ; Starting position
        jmp     fun_mid_s_finish        ; Finish as MID

fun_right_s:
        jsr     fun_mid_s_setup         ; Requested length in D
        jsr     fun_mid_s_pop_string    ; String length in E and requested length <= string length in D
        sec
        sbc     D                       ; Subtract requested length from string length to get starting position
        jmp     fun_mid_s_finish        ; Finish as MID

fun_mid_s:
        jsr     fun_mid_s_setup         ; Requested length in D
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

; When we get here:
; A is the 0-based starting position.
; D is the requested length and is no more than the length of the string less the starting position.
; E is the total string length, which is no longer relevant, so we'll use it for the starting position instead

fun_mid_s_finish:
        sta     E                       ; Starting position in E
        lda     D
        jsr     string_alloc            ; Guaranteed to succeed
        sta     dst_ptr                 ; New space is destination for the copy
        inc     dst_ptr                 ; Move past length byte
        bne     @skip_iny
        iny
@skip_iny:
        sty     dst_ptr+1
        ldax    S0                      ; Copy source is S0 + E
        clc
        adc     E
        bcc     @skip_src_inx
        inx
@skip_src_inx:
        ldy     D
        jsr     copy_y_from
        jmp     push_string

fun_mid_s_error:
        sec
fun_mid_s_done:
        rts

fun_mid_out_of_range:
        raise   ERR_OUT_OF_RANGE

; Do some stuff that is common to LEFT$, RIGHT$, MID$: set D to the requested length.

fun_mid_s_setup:
        ldphaa  string_ptr              ; Remember current string_ptr
        lda     #255
        jsr     string_alloc            ; Allocate a 255-byte string; if success then we know we can alloc later
        plstaa  string_ptr              ; Restore string_ptr
        jsr     pop_int_fp0             ; Length of string returned in A
        bmi     fun_mid_out_of_range    ; Don't allow negative length
        sta     D                       ; Save in D
        rts

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

fun_len:
        jsr     pop_string_s0           ; Length comes back in A, which is what we want
        ldx     #0                      ; High byte is always 0
        jmp     push_int_fp0            ; Push return value

fun_peek:
        jsr     pop_int_fp0             ; Get the argument
        stax    BC                      ; Need it to be a pointer
        ldy     #0                      ; Index 0
        lda     (BC),y                  ; Get the value there
        ldx     #0                      ; High byte is always 0
        jmp     push_int_fp0            ; Push return value

fun_round:
        jsr     pop_fp0
        jsr     round
        jmp     push_fp0        

fun_sgn:
        jsr     pop_fp0
        lda     FP0e                    ; If exponent is 0 then value is 0; return 0
        beq     @done
        ldpha   FP0s                    ; Return the sign of the original value
        lday    #fp_one
        jsr     load_fp0                ; Load 1
        plsta   FP0s                    ; Replace the sign of 1 with the sign of the original number
@done:
        jmp     push_fp0

fun_sqr:
        jsr     pop_fp0
        jsr     flog                    ; Take logarithm
        dec     FP0e                    ; Decrement exponent to divide by 2
        jsr     fexp                    ; Raise again
        jmp     push_fp0

fun_str_s:
        jsr     pop_fp0
        mva     #1, buffer_pos          ; Write at buffer position 1
        jsr     fp_to_string
        ldy     buffer_pos              ; Save the length byte at offset 0
        dey                             ; Don't include the length byte
        sty     buffer
        tya
        jsr     string_alloc            ; Allocate space for the string
        ldy     buffer_pos              ; Already includes the length byte
        mvax    string_ptr, dst_ptr     ; Set up copy destination
        ldax    #buffer                 ; Source
        jsr     copy_y_from
        jmp     push_string

fun_usr:
        jsr     pop_int_fp0             ; Pop the value
        stax    DE                      ; Store in DE because pop_fp0 preserves it
        jsr     pop_int_fp0             ; Pop the address
        stax    BC                      ; Store it so I can use it as a pointer
        ldax    DE                      ; Recover the value
        jsr     @jump_to_user_function
        jmp     push_int_fp0

@jump_to_user_function:
        jmp     (BC)

fun_val:
        jsr     pop_string_s0           ; Get the argument string into S0, returns length in A
        sta     D                       ; Store the length into D
        mvax    #buffer, dst_ptr        ; Copy
        ldax    S0
        ldy     D
        jsr     copy_y_from
        ldx     D
        lda     #0
        sta     buffer,x                ; Terminate string with 0
        ldax    #buffer
        jsr     string_to_fp            ; Parse it
        jmp     push_fp0                ; Push FP0 and return carry from string_to_fp

fun_log:
        jsr     pop_fp0
        jsr     flog
        jmp     push_fp0

fun_exp:
        jsr     pop_fp0
        jsr     fexp
        jmp     push_fp0

fun_cos:
        jsr     pop_fp0
        jsr     fcos
        jmp     push_fp0

fun_sin:
        jsr     pop_fp0
        jsr     fsin
        jmp     push_fp0

fun_tan:
        jsr     pop_fp0
        jsr     ftan
        jmp     push_fp0

