.include "macros.inc"
.include "basic.inc"

; Floating Point Math Routines
;
; Format is single-precision with 40-bit extended significand (5 bytes):
; eeeeeeee stttttt tttttttt tttttttt tttttttt
;
; e = exponent, 8 bits, excess-128 (MSB is inverted)
;     If e = 0 and s = 0 then value = 0
;     If e = 0 and s != 0 then number is subnormal and actual exponent is -127
;     If e >= 1 then actual exponent is e-128 and actual significand is 1+t (implied 1. before t)
; t = significand, 40 bits
;
; The 40-byte value is stored in little-endian format, i.e., lowest byte of significand comes first.
;
; In this module:
; B holds the rounding byte, and C holds the high byte of the exponent.
; Both B and C are used by the normalize function.
; E is used in fdiv to track the exponent adjustment introduced by normalizing a subnormal divisor.
; D and E are also used by the string conversion functions.

; TODO: make sure B and C are handled correctly in each function.

BIAS = 128
MAXDIGITS = 10

.zeropage

; We make a lot of assumptions about the size of Float in this module.
.assert .sizeof(Float) = 5, error
.assert .sizeof(Float::t) = 4, error
.assert .sizeof(Float::e) = 1, error

FP0: .res .sizeof(UnpackedFloat)
FP0t = FP0+UnpackedFloat::t
FP0e = FP0+UnpackedFloat::e
FP0s = FP0+UnpackedFloat::s
FP1: .res .sizeof(UnpackedFloat)
FP1t = FP1+UnpackedFloat::t
FP1e = FP1+UnpackedFloat::e
FP1s = FP1+UnpackedFloat::s
FP2: .res .sizeof(UnpackedFloat::t)
FP3: .res .sizeof(UnpackedFloat::t)

.code

; ; Converts a string in bufer into an FP number in FPA.
; ; If the first character is not a number, then return an error. Otherwise, read up to the first non-digit.
; ; bp = the read position in buffer
; ; Returns the number in FPA and carry clear if ok, carry set if error.

; string_to_fp:
;         ; jsr     clear_fpa               ; Clear FPA
;         ldx     bp                      ; X is the index into the string
;         ldy     #$80                    ; Y counts digits after '.'; starts at -128 and jumps to 0 on '.'
;         lda     buffer,x                ; Check first character
;         cmp     #'-'                    ; Is the first character a minus?
;         php                             ; Remember result of this for later
;         bne     @bypass_increment
; @next_character:
;         inx                             ; Increment to the next character
; @bypass_increment:
;         lda     buffer,x                ; Get the next character
;         cmp     #'.'                    ; Is it the decimal point?
;         bne     @not_decimal_point      ; No
;         tya                             ; Check if we've already seen a decimal
;         bpl     @err_multiple_decimals
;         ldy     #0                      ; Set Y to 0 to count digits after '.'
;         jmp     @next_character

; @not_decimal_point:
;         jsr     char_to_digit           ; Try to make it into a digit
;         bcs     @not_digit              ; Character was not a digit
;         sta     D                       ; Park digit

; ; Multiply FPA by 10 and add in new digit.

;         jsr     mul10_significand
;         bcs     @err_overflow
;         iny                             ; Increment digits after '.'
;         lda     D                       ; Recall the digit
;         clc     
;         adc     FPA+Float::t            ; Add digit to LSB
;         sta     FPA+Float::t
;         bcc     @next_character         ; If no carry then next character
;         inc     FPA+Float::t+1          ; Otherwise increment next byte
;         bne     @next_character         ; etc,
;         inc     FPA+Float::t+2
;         bne     @next_character
;         inc     FPA+Float::t+3
;         beq     @err_overflow           ; If significand rolled over to 0 then overflow
;         jmp     @next_character

; @not_digit:
;         cpy     #$80                    ; Has Y changed at all?
;         beq     @err_not_digit          ; No, so this is an error: we wanted a number and didn't find one
;         lda     buffer,x                ; Load character again; -1 since we've incremented X
;         cmp     #'E'                    ; Is it 'E'?
;         beq     @handle_e               ; Yes

; ; Update the exponent and finish.

; @finish:
;         tya                             ; Exponent adjustment to A
;         bpl     @set_exponent           ; If adjustment is positive then use it
;         lda     #0                      ; Otherwise make it 0
; @set_exponent:
;         sta     D                       ; Use D to temporarily store adjustment
;         sec
;         lda     FPA+Float::e
;         sbc     D
;         bvs     @err_overflow           ; Adjusting E might cause signed overflow
;         sta     FPA+Float::e            ; Store exponent
;         plp                             ; Go get the '-' comparison from earlier
;         bne     @positive               ; There was no '-' at the start of the string
;         ; jsr     fneg
;         bpl     @err_overflow_2         ; Overflow if we were expecting negative but number is positive
;         bmi     @done

; @positive:
;         lda     FPA+Float::t+3
;         bmi     @err_overflow_2         ; Overflow if we were expecting positive but number is negative
; @done:
;         stx     bp                      ; Update bp
;         clc                             ; Signal success
;         rts

; @err_overflow_in_e:
;         pla                             ; Errors that require two pops
; @err_overflow:
; @err_not_digit:
; @err_multiple_decimals:
;         pla                             ; Errors that require one pop
; @err_overflow_2:
;         sec                             ; Signal failure
;         rts

; ; There can be 1-3 exponent digits after 'E' optionally prefixed by '-'.
; ; Parse the number and store in FPA exponent.
; ; Checks for digits also handle the case of the string ending after 'E' or '-'.

; @handle_e:
;         inx                             ; Skip 'E'
;         lda     buffer,x                ; First character
;         cmp     #'-'                    ; Is it minus?
;         php                             ; Save the result for later
;         bne     @bypass_increment_e
; @next_character_e:
;         inx                             ; Skip the minus
; @bypass_increment_e:
;         lda     buffer,x                ; Next character
;         jsr     char_to_digit           ; Try to parse as digit
;         bcs     @finish_e               ; Was not digit
;         sta     D                       ; Park digit in D
;         lda     FPA+Float::e            ; Get exponent
;         asl     A                       ; Exponent *2
;         bcs     @err_overflow_in_e
;         asl     A                       ; *4
;         bcs     @err_overflow_in_e
;         adc     FPA+Float::e            ; *5, carry guaranteed to be clear
;         bcs     @err_overflow_in_e
;         asl     A                       ; *10
;         bcs     @err_overflow_in_e
;         adc     D                       ; Add in the new digit
;         bcs     @err_overflow_in_e
;         bmi     @err_overflow_in_e      ; If it goes negative then fail
;         sta     FPA+Float::e
;         jmp     @next_character_e

; @finish_e:
;         plp                             ; Get the '-' comparison from before
;         bne     @finish                 ; If it wasn't negative then all done
;         lda     FPA+Float::e            ; Negate exponent
;         eor     #$FF
;         sta     FPA+Float::e
;         inc     FPA+Float::e
;         jmp     @finish

; ---------------------------------------------------------------------------------------------------------------------

; Loads a new Float value from memory into FP0 or FP1.
; AY = a pointer to the value to load
; X = either #FP0 or #FP1

; Y indexes Float starting at position 0 so make sure everything is in the right place.
.assert Float::t = 0, error
.assert Float::e = 4, error

load_fpx:
        stay    BC                      ; FP value address into DE
        ldy     #0                      ; Start with low byte of significand
        lda     (BC),y
        sta     UnpackedFloat::t,x
        iny
        lda     (BC),y
        sta     UnpackedFloat::t+1,x
        iny
        lda     (BC),y
        sta     UnpackedFloat::t+2,x
        iny
        lda     (BC),y                  ; High 7 bits of significand plus sign
        and     #$80                    ; Isolate high bit
        sta     UnpackedFloat::s,x      ; Store sign (only bit 7 is signifncant)
        lda     (BC),y                  ; Reload
        and     #$7F                    ; Isolate significand
        sta     UnpackedFloat::t+3,x    ; Store high 7 bits of significand
        iny     
        lda     (BC),y                  ; Exponent
        beq     @subnormal_or_zero      ; Handle as subnormal; significand MSB will be 0 in this case
        sta     UnpackedFloat::e,x      ; Store exponent
        lda     #$80                    ; High bit of significand
        ora     UnpackedFloat::t+3,x    ; OR with high byte
        sta     UnpackedFloat::t+3,x    ; Save back
        rts

@subnormal_or_zero:
        lda     #$01                    ; Exponent is -127 ($01)
        sta     UnpackedFloat::e,x      ; Store exponent
        rts

; Stores the value in FP0 or FP1 as a Float value in memory.
; AY = destination address
; X = either #FP0 or #FP1

store_fpx:
        stay    BC                      ; FP value address into BC
        ldy     #0                      ; Start with low byte of significand
        lda     UnpackedFloat::t,x
        sta     (BC),y
        iny
        lda     UnpackedFloat::t+1,x
        sta     (BC),y
        iny
        lda     UnpackedFloat::t+2,x
        sta     (BC),y
        iny
        lda     UnpackedFloat::t+3,x    ; High byte of significand
        bpl     @subnormal_or_zero      ; MSB of significand is 0 so this is subnormal or zero
        and     #$7F                    ; Set MSB to 0
        ora     UnpackedFloat::s,x      ; OR in the sign bit
        sta     (BC),y                  ; Save
        iny
        lda     UnpackedFloat::e,x
        sta     (BC),y                  ; Store
        rts

@subnormal_or_zero:
        ora     UnpackedFloat::s,x      ; OR in the sign bit
        sta     (BC),y                  ; Save
        iny
        lda     #0
        sta     (BC),y                  ; Save exponent as zero
        rts

; Swaps FP0 and FP1.

swap_fp0_fp1:
        ldy     #.sizeof(UnpackedFloat)-1
@next_byte:
        lda     FP1,y
        ldx     FP0,y
        stx     FP1,y
        sta     FP0,y
        dey
        bpl     @next_byte
        rts

; Copies FP0 to FP1.

copy_fp0_fp1:
        lda     FP0s
        sta     FP1s
        lda     FP0e
        sta     FP1e
        ldx     #FP1t

; Copies the significand of FP0 to another register.
; X = either #FP1t, #FP2, or #FP3

copy_significand:
        lda     FP0t
        sta     0,x
        lda     FP0t+1
        sta     1,x
        lda     FP0t+2
        sta     2,x
        lda     FP0t+3
        sta     3,x
        rts

; Sets either FP0 or FP1 to zero.
; X = either #FP0 or #FP1

clear_fpx:
        lda     #0
        sta     UnpackedFloat::e,x
        sta     UnpackedFloat::s,x

; Fall through

; Clears the significand of FP0 or FP1, or FP2 or FP3.
; X = either #FP0t, #FP1t, #FP2, or #FP3
; Returns 0 in A.

clear_significand:
        lda     #0
        sta     0,x
        sta     1,x
        sta     2,x
        sta     3,x
        rts

; Checks if FP0 or FP1 is zero.
; Returns with the zero flag set and 0 in A if zero, otherwise the zero flag will be clear.
; X = either #FP0 or #FP1

; TODO: add fp0_is_zero

fpx_is_zero:
        lda     UnpackedFloat::t,x      ; OR all the significand bytes together
        ora     UnpackedFloat::t+1,x
        ora     UnpackedFloat::t+2,x
        ora     UnpackedFloat::t+3,x
        rts

; Generates the two's complement of the FP0 extended significand by subtracting it from 0.
; X SAFE, Y SAFE, BC SAFE, DE SAFE

negate_significand:
        sec
        lda     #0
        sbc     FP0t
        sta     FP0t
        lda     #0
        sbc     FP0t+1
        sta     FP0t+1
        lda     #0
        sbc     FP0t+2
        sta     FP0t+2
        lda     #0
        sbc     FP0t+3
        sta     FP0t+3
        lda     #0
        sbc     FP2
        sta     FP2
        rts

; Adds the significands of FP0 and FP1.
; Returns the high byte of the result in A.

add_significands:
        clc                     
add_significands_with_carry:
        lda     FP0t                    ; Add the significands
        adc     FP1t
        sta     FP0t
        lda     FP0t+1
        adc     FP1t+1
        sta     FP0t+1
        lda     FP0t+2
        adc     FP1t+2
        sta     FP0t+2
        lda     FP0t+3
        adc     FP1t+3
        sta     FP0t+3
        lda     FP2                     ; Extended significand
        adc     #0                      ; Extended significand of FP1 is always 0
        sta     FP2
        rts

; Multiplies the FPA significand by 10. Copies the FP0 value into FP1.
; On return the carry will be set if the multiplication caused an overflow.
; On overflow, the original value can be recovered from FP1.
; Y SAFE, BC SAFE, DE SAFE

mul10_significand:
        ldx     #FP1t
        jsr     copy_significand
        jsr     @shift_significand      ; *2
        bcs     @overflow
        jsr     @shift_significand      ; *4
        bcs     @overflow
        jsr     add_significands        ; *5
        bcs     @overflow
        jsr     @shift_significand      ; *10
@overflow:
        rts

; Shifts the signifiand of FPA left, multiplying it by 2.
; TODO: merge with other cases like div10_significand.

@shift_significand:
        asl     FP0t
        rol     FP0t+1
        rol     FP0t+2
        rol     FP0t+3
        rts

; Divides the FP0 significand by 10.
; Returns the remainder in A.
; Uses X to keep track of the shift count.
; Y SAFE, BC SAFE, DE SAFE

div10_significand:
        lda     #0                      ; Initialize remainder to 0
        ldx     #32                     ; 32 bits
@next_bit:
        asl     FP0t                    ; LSB of FPA+1 (least significant byte) is now 0
        rol     FP0t+1
        rol     FP0t+2
        rol     FP0t+3
        rol     A                       ; Bits from significand move into A
        cmp     #10                     ; C ("don't borrow") set if A>=10
        bcc     @not_10                 ; It's <10
        inc     FP0t                    ; Increment quotient
        sbc     #10                     ; C will still be set here
@not_10:
        dex
        bne     @next_bit               ; More bits to shift
        rts

; Assumes that the 32-bit value in the top two bytes of FP0 signifcand is an integer and converts it to a float.

int_to_fp:
        mva     #159, FP0e              ; Have to shift left 31 places (to exponent 128) to get original value
        mva     #0, C                   ; Set exponent high byte to 0
        sta     B                       ; Set round register to 0
        sta     FP2                     ; Clear low byte of extended significand
        lda     FP0t+3                  ; Check sign bit
        and     #$80                    ; Isolate sign bit
        sta     FP0s                    ; Store
        bpl     @positive               ; Was positive, carry on
        dec     FP2                     ; Sign-extend to 40 bits
        jsr     negate_significand      ; Number was negative so negate the significand
@positive:
        jmp     normalize     

; Returns the greatest 32-bit integer less than or equal to the input value.
; To generate the integer value we shift the significand (and adjust the exponent) until the exponent is 0; the
; integer part will now be to the left of the binary point. But because that would push the integer part off the
; left end of the significand field, instead we adjust until the exponent is 31, at which point the integer value
; will be in the significand field of FP0.

truncate_fp_to_int:
        mva     #0, FP2                 ; Extend to 40 bits in case we have to shift right
        lda     FP0e                    ; Get the exponent
        sec
        sbc     #160                    ; Target exponent value is 31 (159 with bias), but subtract 32 (160)
        tay                             ; Otherwise A is -(number of shifts) - 1, so we pre-increment and check for 0
        bcc     @decrement              ; If we borrowed to subtract 160, then E < 160 or E <= 159; ok!
        rts                             ; Otherwise return with carry set

@shift:
        jsr     shift_right             ; Shift right
@decrement:
        iny                             ; For example if E was 159 then A = (159-160) = -1, so INY gives 0 and we stop
        bne     @shift                  ; If not 0 then continue
        lda     FP0s                    ; Check the sign bit
        bpl     @positive               ; If positive then continue
        jsr     negate_significand      ; If negative then negate
@positive:
        clc                             ; Signal success
        rts

; Converts FP number in FP0 into a string.
; Writes the string to buffer at the position specified by bp. Does not perform any error checking; there must 
; be enough space in the buffer for the write to succeed.

ten: .byte $00, $00, $00, $20, 131
string_max: .byte $00, $00, $00, $00, 160       ; 2^32     (4,294,967,296  )
string_min: .byte $CC, $CC, $CC, $4C, 156       ; 2^31/10  (  429,496,729.6)

fp_to_string:
        lda     FP0s                    ; Check for negative value
        bpl     @positive               ; Nope
        ldx     bp                      ; Write index
        lda     #'-'                    ; Minus sign
        sta     buffer,x
        inc     bp                      ; Update index

; Handle 0 as a special case.
; The number is 0 if the significand is zero regardless of exponent.

@positive:
        mva     #0, E                   ; E keeps track of how much we have scaled up or down
        sta     D                       ; D is the number of generated digits
        sta     FP0s                    ; Also set sign to positive since we already printed '-'
        ldx     #FP0
        jsr     fpx_is_zero
        bne     @maybe_scale_up
        ldx     bp                      ; Write index
        lda     #'0'
        sta     buffer
        inc     bp                      ; Update index
        rts

@scale_up:
        lday    #ten
        ldx     #FP1
        jsr     load_fpx
        jsr     fmul                    ; Multiply FP0 by 10
        dec     E                       ; Have to divide by 10 to get back to original number
@maybe_scale_up:
        debug $00
        lday    #string_min             ; Load minimum value
        ldx     #FP1                    ; Into FP1
        jsr     load_fpx
        jsr     fcmp                    ; Carry clear (borrow set) means FP0 < FP1 so we have to scale up
        debug $01
        bcc     @scale_up
        bcs     @maybe_scale_down       ; Unconditional skip past scale down code
@scale_down:
        jmp $0000 ; TODO: remove
        lday    ten
        ldx     #FP1
        jsr     load_fpx
        jsr     fdiv                    ; Divide FP0 by 10
        inc     E                       ; Have to multiply by 10 to get back to original number
@maybe_scale_down:
        debug $10
        lday    #string_max             ; Load maximum value
        ldx     #FP1                    ; Into FP1
        jsr     load_fpx
        jsr     fcmp                    ; Carry set (borrow clear) means FP0 >= FP1 so we have to scale down
        debug $11
        bcs     @scale_down
        jsr     truncate_fp_to_int      ; Make into a 32-bit integer
        debug $12
        jsr     generate_digits

; There are D generated digits.
; The adjustment factor is 10^E, that is, current number * 10^E = original number.
;   * If E >= 0 then print D digits, E extra 0s at the end; length = D + E
;   * If -E < D then print D - (-E) digits, '.', -E digits
;   * If -E >= -D (i.e., D - (-E) <= 0) then print '0.', -(D - (-E)) 0s, then D digits

@output:
        clc                             ; It will be convenient for carry to be clear shortly
        ldx     bp                      ; Load buffer position into X
        lda     E
        bpl     @whole                  ; Branch to @whole for the E >= 0 cases
        eor     #$FF                    ; It's easier to deal with E if it's positive so negate it giving (-E - 1)
        adc     #1                      ; Add 1 to complete negation
        cmp     #11                     ; Check if more than 10 digits
        bcs     @scientific             ; More than 10 digits; print in scientific notation
        sta     E                       ; E = -E
        lda     D                       ; Calculate D - E
        sec
        sbc     E
        beq     @initial_zero           ; If 0 or negative then print initial '0.'
        bmi     @initial_zero
        tay
        jsr     output_y_digits
        iny                             ; Output no 0s after the decimal; Y is -1 so INY will increase it to 0
        mva     E, D                    ; Output E digits later
@decimal:
        lda     #'.'                    ; Output decimal point
        sta     buffer,x
        inx
        jsr     output_y_zeros          ; Output (possibly zero) leading zeros
        ldy     D
        jsr     output_y_digits
@done:
        stx     bp
        rts

@initial_zero:
        eor     #$FF                    ; A is E - D but we need D - E so negate
        tay
        iny                             ; +1 to complete negation; will output this many 0s after the decimal point
        lda     #'0'                    ; Output '0' before decimal
        sta     buffer,x
        inx
        jmp     @decimal

@digits_before_decimal:
        eor     #$FF                    ; A is E - D but we need D - E so negate
        tay
        iny                             ; +1 to complete negation
        jsr     output_y_digits
        mva     E, D                    ; E is the number of digits remaining after decimal point
        ldy     #0                      ; Number of zeros after decimal point
        jmp     @decimal

@whole:
        adc     D                       ; Add in D
        cmp     #11                     ; Check if more than 10 digits
        bcs     @scientific             ; More than 10 digits; print in scientific notation
        ldy     D                       ; Output D digits
        jsr     output_y_digits
        ldy     E                       ; Followed by E zeros
        jsr     output_y_zeros
        jmp     @done

@scientific:
        ldy     #1                      ; Print 1 digit before the decimal point
        jsr     output_y_digits
        lda     #'.'                    ; Output decimal point
        sta     buffer,x
        inx
        ldy     D                       ; Output the remaining digits
        dey                             ; Minus one for the first digit
        jsr     output_y_digits
        lda     #'E'                    ; Exponent
        sta     buffer,x
        inx

; Print the exponent value.
; We could just suffix the number with "E" followed by the negated E value.
; But we've shifted the decimal D-1 places to the left, so we need to add D-1 to the exponent.

        dec     D                       ; Account for missing digit
        lda     E                       ; Start with exponent
        clc
        adc     D                       ; Add D
        bpl     @positive_e
        tay                             ; Stash exponent value in Y
        lda     #'-'
        sta     buffer,x
        inx
        dey                             ; We're going to negate so decrement E while it's still stashed in Y
        tya                             ; Get exponent value back from Y
        eor     #$FF                    ; Complete negation
@positive_e:
        sta     FP0t                    ; Save in significand
        mva     #0, FP0t+1
        sta     FP0t+2
        sta     FP0t+3
        sta     D                       ; Reset number of digits and scaling factor
        sta     E
        stx     bp                      ; generate_digits will clobber X so save it
        jsr     generate_digits
        ldx     bp                      ; Recover X
        ldy     D
        jsr     output_y_digits
        ldy     E
        jsr     output_y_zeros
        jmp     @done        

; Generate digits. Repeatedly divide FPA by 10, generate remainder in A.
; Will always generate at least one digit, which cannot be zero because we
; handled zero above.
; Ignore any initial zeros and increment E instead.

generate_digits:
        plstaa  BC                      ; Save return address
@next_digit:
        ldx     #FP0
        jsr     fpx_is_zero             ; Check if FP0 significand zero; this will never be true the first time
        beq     @no_more_digits         ; If zero then done generating digits; go to output
        jsr     div10_significand       ; The remainder in A is the digit
        tax                             ; Move remainder into X
        ora     D                       ; Or with number of digits; tests if both are zero
        beq     @skip_zero              ; If so then skip this zero
        txa                             ; Otherwise get the digit back
        clc                     
        adc     #'0'                    ; Convert to ASCII
        pha                             ; Use stack to store digits
        inc     D                       ; Number of generated digits += 1
        bne     @next_digit             ; Unconditional

@skip_zero:
        inc     E                       ; We divided significand by 10 without emitting a digit, so increase E
        jmp     @next_digit             ; Keep generating digits

@no_more_digits:
        ldphaa  BC                      ; Restore return address
        rts

; Output Y (possibly zero) digits from the stack.
; The digits are on the stack, behind the JSR return address, so we pop the return address off, stash it in BC, 
; and then restore it before returning.
; X = the current buffer position (updated)
; BC SAFE

output_y_digits:
        plstaa  BC                      ; Save return address in BC
@output_digit:
        dey                             ; Pre-decrement digit count
        bmi     @done                   ; If it's gone negative then return
        pla
        sta     buffer,x
        inx
        bne     @output_digit           ; Unconditional

@done:
        ldphaa  BC                      ; Restore return addresss
        rts

; Output Y (possibly zero) zero digits.
; X = the current buffer position (updated)
; BC SAFE, DE SAFE

output_y_zeros:
        lda     #'0'                    ; Prepare to output '0'
@output_zero:
        dey
        bmi     @done
        sta     buffer,x
        inx
        bne     @output_zero            ; Unconditional
@done:
        rts


string_to_fp:
        ldx     #FP0
        jsr     clear_fpx               ; Reset to zero
        clc                             ; Signal success
        rts

; Converts the character in A into a digit.
; Returns the digit in A, carry clear if ok, carry set if error.
; X SAFE, Y SAFE, BC SAFE, DE SAFE

char_to_digit:
        sec                             ; Set carry
        sbc     #'0'                    ; Subtract '0'; maps valid values to range 0-9 and other values to 10-255
        cmp     #10                     ; Sets carry if it's in the 10-255 range
        rts

; Utility function to shift the 40-bit extended significand of FP0 right by one bit and increment exponent.
; The caller is responsible for testing for exponent overflow before calling.

shift_right:
        lsr     FP2                     ; Right shift low byte of FP2 plus FP0t
shift_right_from_carry:
        ror     FP0t+3
        ror     FP0t+2
        ror     FP0t+1
        ror     FP0t
        ror     B                       ; Rotate carry into rounding register
        inc     FP0e                    ; Increase exponent
        bne     @skip                   ; Skip increment of exponent high byte FP0e did not roll over
        inc     C                       ; Increment high byte
@skip:
        rts

; Adjusts the 16-bit unsigned biased exponent of FP0 (zero-extended to C) by first adding the value in X
; and then subtracting the value in Y.

adjust_exponent:
        debug $C0
        clc                             ; Clear carry to prepare for add
        txa                             ; Get the value to add from X
        ldx     #0                      ; X is now the high byte
        adc     FP0e                    ; Add in FP0 exponent
        sta     FP0e                    ; Update FP0 exponent
        bcc     @no_carry               ; If carry clear then don't increment high byte
        inx                             ; Increment high byte
@no_carry:
        sec                             ; Set carry to prepare for subtraction
        tya                             ; Get value to subtract from Y
        eor     #$FF                    ; Take one's complement; the +1 to get two's complement comes from carry
        adc     FP0e                    ; Do the "subtraction" (adding one's complement plus sign)
        sta     FP0e                    ; Save again
        bcs     @no_borrow              ; If not borrowing then don't have to decrement high byte
        dex                             ; Decrement high byte
@no_borrow:
        stx     C                       ; Store in C
        rts

; Shifts the 40-bit FP0 extended significand one place to the right and re-attempts normalization.
; Invoked from normalize when the significand doesn't fit into 32 bits.

shift_right_normalize:
        jsr     shift_right             ; Use shift_right to shift the remaining 32 bits

; Fall through

; Normalizes the value in FP0. Normalization shifts the FP0 significand (adjusting the exponent each time)
; until the most-significant bit is 1. The normalize function acts on the 40-bit FP0 extended significand and
; normalizes to the 32-bit FP0 significand.
; Normalization handles several different cases:
;   * If FP2 (the high byte of the 40-bit significand) has a value (if the significand is >=2),
;   then shift right (increase exponent) until the value fits into the 32-bit significand. This may happen if an
;   addition or subtraction overflowed the 32-bit significand.
;   * If the biased exponent is <-31, then return zero. This is an underflow condition; we cannot bring the exponent
;   within range without shifting all the bits of the exponent away.
;   * If the biased exponent is <1, then shift right (increase exponent) until it is 1.
;   * If the 32-bit significand, and the round register B, are zero, then return zero. This avoids fruitlessly
;   shifting left in search of a 1 to put in the most-significant bit.
;   * Shift left (decrease exponent) until a 1 bit is in the most-significant bit of the significand, or the exponent
;   reaches -127.
;   * If the value in the rounding register B is >=128 (MSB is set), then add 1 to the significand.
;   * If adding 1 to the significand for rounding caused the significand to increase to be >=2, then shift right
;   (increase exponent) once again.
;   * If the exponent is >127, fail with an overflow error.
; Otherwise, return the final result.

normalize:

; First check if there are any bits set in the low byte of FP2, indicating the significand is >= 2.

        lda     FP2                     ; Check first extension byte
        debug $80
        bne     shift_right_normalize   ; There are significant bits, so shift right and try again

; Entry point if the significand fits within 32 bits.
; Check if the biased exponent is <1.

        lda     C                       ; High byte of exponent
        bmi     shift_right_normalize   ; It's negative so definitely too low
        lda     FP0e                    ; Not negative, but exponent might still be zero
        beq     shift_right_normalize

; Check if FP0 is zero. If so then set exponent to lowset possible value and return.
; If FP0 is not zero then it means that left normalization is guaranteed to end: either the sign bit is 0, and one of
; the other significand bits is 1 (since the significand overall is not zero); or the sign bit is 1, and eventually
; we'll see a 0 bit, because we shift in 0s from the right.

@check_zero:
        ldx     #FP0
        debug $81
        jsr     fpx_is_zero             ; Check if FP0 is zero
        debug $82
        bne     @coarse
        ldx     B                       ; Check round
        bne     @coarse                 ; Round is not zero so we can still find a 1 bit somewhere
        lda     #0                      ; It's really zero; set lowest possible exponent and return
        sta     FP0e
        clc                             ; Signal success
        rts

@coarse:
        debug $90
        ldy     FP0t+3                  ; Get high byte of significand
        bne     @fine                   ; If not 0 then try fine shift

; The high byte is 0, so shift left 8 bits using byte moves.

@coarse_shift:
        lda     FP0e                    ; Get exponent
        sec
        sbc     #8                      ; Trial subtraction of 8
        bcc     @fine                   ; If subtracting required a borrow then try fine shift
        beq     @fine                   ; If it went to 0 then can't apply coarse shift; do fine shift instead
        sta     FP0e                    ; Otherwise update exponent
        lda     FP0t+2
        sta     FP0t+3                  ; Store new high byte
        lda     FP0t+1                  ; Shift other bytes
        sta     FP0t+2          
        lda     FP0t
        sta     FP0t+1
        lda     B                       ; Rounding register goes into FP0t
        sta     FP0t
        mva     #0, B                   ; Clear rounding register
        beq     @coarse                 ; Unconditional

@fine_shift:
        asl     B                       ; Shift left one bit starting from rounding register
        rol     FP0t
        rol     FP0t+1
        rol     FP0t+2
        rol     FP0t+3
        dec     FP0e

@fine:
        debug $A0
        lda     FP0t+3                  ; Get the high byte of significand
        bmi     @round                  ; Significand is normalized
        lda     FP0e                    ; Get exponent
        cmp     #1                      ; Make sure not already minimum value (-127)
        bne     @fine_shift             ; Okay to shift; otherwise leave as subnormal and fall through

; Round the result, which will possibly require another right shift.

@round:
        asl     B                       ; Shift rounding register high bit into carry
        debug $B0
        bcc     @done                   ; If nothing there then no rounding, otherwise round away from zero
        ldx     #FP1t
        jsr     clear_significand
        sta     B                       ; Also clear rounding register since it has been used to round up
        jsr     add_significands_with_carry
        debug $B1
        beq     @done                   ; If the value written to FP2 was 0 then all done
        jsr     shift_right_from_carry  ; Otherwise have to shift right again

@done:
        clc                             ; Signal success
        rts

swap_fadd:
        jsr     swap_fp0_fp1            ; Swap FP0 and FP1 in order to get value with larger exponent in FP0

; Fall through

; Performs FP0 + FP1, leaving the sum in FP0 and possibly modifying FP1.

fadd:
        mva     #0, B                   ; Initialize the rounding register to 0
        sta     C                       ; Clear the extended exponent register
        sta     FP2                     ; Also clear FP0 extended significand
        lda     FP1e                    ; FP0 exponent
        sec
        sbc     FP0e                    ; Compare exponents: FP1e - FP0e
        beq     @equal_exponents        ; Exponents are equal, just go ahead to addition
        bcc     swap_fadd               ; If borrow then FP0e is larger, so swap and try again
        bmi     @return_larger          ; Exponent difference >127 so addition has no effect
        tax                             ; Exponent different is in X and is >=0

; FP0 exponent is less than FP1 exponent, so shift FP0 significand left X places to align binary points.

@align:
        jsr     shift_right
        dex
        bne     @align

; If both arguments have the same sign, just add and use the sign of FP0.
; If one is negative, put it in FP0 and negate it.

@equal_exponents:
        lda     FP0s
        eor     FP1s                    ; XOR signs together
        bpl     @equal_signs            ; Signs are the same
        lda     FP0s                    ; Check the FP0 sign
        bmi     @fp0_negative           ; FP0 is already the negative one
        jsr     swap_fp0_fp1            ; FP1 was negative, but swap them so now FP0 is negative
@fp0_negative:
        jsr     negate_significand      ; This makes the sign bit of FP0t match FP0s
@equal_signs:
        jsr     add_significands
        tax                             ; Temporarily store in X
        bpl     @positive               ; Result was positive
        jsr     negate_significand      ; Result was negative so negate    
@positive:
        txa                             ; Recover high byte of result
        and     #$80                    ; Isolate sign bit (which will be 1)
        eor     FP1s                    ; Result is neg if FP1 was neg or result is now neg but not both
        sta     FP0s
@finish:
        jmp     normalize               ; Normalize result and return

; The difference between exponents is >127, so just return the larger number (identified by N flag).

@return_larger:
        bmi     @finish                 ; A was larger so just return
        jsr     swap_fp0_fp1            ; Otherwise swap
        jmp     @finish

; Subtract FP1 from FP0.
; Simply negates the sign of FP1 and forward to fadd.

fsub:
        lda     FP1s
        eor     #$80
        sta     FP1s
        jmp     fadd

; Multiplies FP0 and FP1, leaving the normalized result in FP0.

fmul:
        ldx     #FP0
        jsr     fpx_is_zero             ; Is FP0 zero?
        beq     @return_zero            ; Yes, just return
        ldx     #FP1
        jsr     fpx_is_zero             ; Test FP1
        bne     @do_multiply
@return_zero:
        ldx     #FP0
        jsr     clear_fpx               ; Return zero
        clc                             ; Signal success
        rts

@do_multiply:

; Do 32 bit multiplication of FP0 and FP1 significands.

        lda     FP0t                    ; Copy FP0t into FP3
        sta     FP3
        lda     FP0t+1
        sta     FP3+1
        lda     FP0t+2
        sta     FP3+2
        lda     FP0t+3
        sta     FP3+3
        ldx     #FP2                    ; Clear the extended significand of FP0
        jsr     clear_significand
        ldy     #32                     ; 32 multiplication cycles

@next_bit:
        lsr     FP1t+3                  ; Shift FP1 significand right              
        ror     FP1t+2
        ror     FP1t+1
        ror     FP1t
        bcc     @skip                   ; FP1 LSB was 0 so don't need to add anything
        clc                             ; Add significand in FP3 to FP2 (TODO: try to use add_significands)      
        lda     FP2
        adc     FP3
        sta     FP2
        lda     FP2+1
        adc     FP3+1
        sta     FP2+1
        lda     FP2+2
        adc     FP3+2
        sta     FP2+2
        lda     FP2+3
        adc     FP3+3                   ; This will never overflow because high bit of FP2 will always be zero
        sta     FP2+3
@skip:
        ror     FP2+3                   ; 64-bit right shift; rotate moves carry from add into high bit
        ror     FP2+2
        ror     FP2+1
        ror     FP2
        ror     FP0t+3
        ror     FP0t+2
        ror     FP0t+1
        ror     FP0t
        dey                             ; Done with one cycle
        bne     @next_bit

; The 64-bit product in FP0t and FP2 is in the range 0 to almost 4, and the binary point is between
; bits 61 and 62 (assuming MSB is 63). Use byte copy to shift it 32 places into FP0t with the next-lower byte in
; the rounding register.

        lda     FP0t+3                  ; Bits 24-31 go into rounding register
        sta     B
        lda     FP2+3
        sta     FP0t+3
        lda     FP2+2
        sta     FP0t+2
        lda     FP2+1
        sta     FP0t+1
        lda     FP2
        sta     FP0t
        mva     #0, FP2                 ; Clear extended significand

; Calculate exponent and sign.

        ldx     FP1e                    ; Add FP1e to FP0e
        ldy     #BIAS                   ; Subtract bias
        jsr     adjust_exponent         ; Do the math stuff; C is high byte of exponent
        inc     FP0e                    ; Account for the binary point being off by 1
        lda     FP0s                    ; Get sign of FP0
        eor     FP1s                    ; If both are pos or neg, then pos, else neg
        sta     FP0s
        jmp     normalize               ; Normalize and return

; Divides FP0 by the value in FP1, returning the quotient in FP0.
; Shifts the dividend left into the FP0 extended significand. After each shift, check if it's greater than the
; dividend; if so then add one to the significand. After 32 operations, the quotient will be in the lower 32 bits
; of FPA and the remainder will be in the upper 32 bits.

fdiv:
        ldx     #FP0
        jsr     fpx_is_zero             ; Is FP0 zero?
        beq     @return_zero            ; Yes, just return
        ldx     #FP1
        jsr     fpx_is_zero             ; Test FP1
        bne     @initalize
        sec                             ; Error if FP1 is zero
        rts

@return_zero:
        ldx     #FP0
        jsr     clear_fpx               ; Return zero
        clc                             ; Signal success
        rts

@initalize:
        mva     #0, FP2                 ; Clear extended significand
        mva     #BIAS, D                ; D keeps track of how much bias to add

; We have to shift the dividend right one place in order to ensure that it is smaller than the divisor. This means
; we'd have to shift the least-significant bit into some other location (presumably B). But the very first thing we
; do in the @divide subfunction is shift the dividend left one place. So instead of shifting right into B and then
; having to shift B left, we just don't shift anything and, the first time through, JSR to a point in @divide after the
; shift left.

        mva     #1, B
        jsr     @divide_skip_shift
        ldx     #3                      ; Store this value FP3 position 3
        bpl     @store_quotient         ; Unconditional

@next_quotient_byte:
        mva     #1, B                   ; Set B to 1 in order to generate 8 quotient bits
        jsr     @divide                 ; Call divide function; next 8 bits of quotient bits now in B
@store_quotient:
; TODO: build quotient in FP0 and use copy_significand to copy original significand to FP3
        lda     B                       ; Get quotient byte
        sta     FP3,x
        dex
        bpl     @next_quotient_byte     ; If X is still >= 0 then more bytes to do
        mva     FP3, FP0                ; Quotient is in FP3; copy it into FP0
        mva     FP3+1, FP0+1
        mva     FP3+2, FP0+2
        mva     FP3+3, FP0+3

; Calculate exponent and sign.

        ldy     FP1e                    ; Subtract FP1e from FP0e
        ldx     D                       ; Add bias
        jsr     adjust_exponent         ; Do the math stuff; C is high byte of exponent
        lda     FP0s                    ; Get sign of FP0
        eor     FP1s                    ; If both are pos or neg, then pos, else neg
        sta     FP0s
        jmp     normalize               ; Normalize and return

; Compare the dividend in FP0+FP2 to the divisor FP1.
; If divisor is <= than dividend, shift a 1 bit into quotient byte in B, else shift a 0. Do this until a 1 bit rotates
; out of B. The value of B on entry determines how many times this function will carry out this operation. If it is
; initialized to 1, then it will loop 8 times.

@divide:
        asl     FP0t                    ; Shift dividend left one bit
        rol     FP0t+1
        rol     FP0t+2
        rol     FP0t+3
        rol     FP2
@divide_skip_shift:
        debug $40
        sec                             ; If FP2 is >0 then divisor FP1 <= dividend FP2 so we want carry to be set
        lda     FP2                     ; Dividend extended significand
        bne     @compare_done
        lda     FP0t+3
        cmp     FP1t+3                  ; Sets carry (clears borrow) if divisor FP1 <= dividend FP2
        bne     @compare_done           ; If not equal then result is in carry; if equal then check next byte, etc.
        lda     FP0t+2
        cmp     FP1t+2
        bne     @compare_done
        lda     FP0t+1
        cmp     FP1t+1
        bne     @compare_done
        lda     FP0t
        cmp     FP1t
@compare_done:
        bcc     @skip_subtract          ; If carry clear (borrow set) then divisor > dividend; don't subtract
        lda     FP0t
        sbc     FP1t
        sta     FP0t
        lda     FP0t+1
        sbc     FP1t+1
        sta     FP0t+1
        lda     FP0t+2
        sbc     FP1t+2
        sta     FP0t+2
        lda     FP0t+3
        sbc     FP1t+3
        sta     FP0t+3
        lda     FP2                     ; Possibly have to borrow from extended significand
        sbc     #0
        sta     FP2
        sec                             ; Set carry so we roll 1 bit into quotient
@skip_subtract:
        rol     B                       ; Roll the carry left into quotient
        bcc     @divide                 ; Continue if 1 bit has not emerged from B
        rts

; Compares FP0 with FP1.
; Returns flags in the same manner as the CMP instruction: zero flag is set if numbers are equal and carry set if
; FP0 >= FP1.

fcmp:
        lda     FP1s                    ; Sign of FP1 (note registers 0 and 1 are reversed here)
        cmp     FP0s                    ; Subtract sign of FP0
        beq     @same_sign              ; If same sign then continue
        rts                             ; Carry set if FP1s was negative and FP0s was positive -> FP0 is greater

@same_sign:
        lda     FP0e                    ; FP0 exponent
        cmp     FP1e                    ; Subtract FP1 exponent 1
        beq     @same_e                 ; If same exponent then continue
        rts                             ; Carry set if FP0e was greater -> FP0 is greater

@same_e:
        lda     FP0t+3                  ; Compare significands (just 32 bits)
        cmp     FP1t+3
        bne     @done
        lda     FP0t+2
        sbc     FP1t+2
        bne     @done
        lda     FP0t+1
        sbc     FP1t+1
        bne     @done
        lda     FP0t
        sbc     FP1t
@done:
        rts                             ; Flags will be set correctly here
