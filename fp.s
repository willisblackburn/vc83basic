.include "macros.inc"
.include "basic.inc"

; Floating Point Math Routines
;
; Format is single-precision with 40-bit extended significand (5 bytes):
; stttttt tttttttt tttttttt tttttttt eeeeeeee
;
; s = sign
; t = fractional part of significand, 31 bits, lowest byte first
; e = exponent, 8 bits, excess-127 (MSB is inverted)
;     If e = 0 and s = 0 then value = 0
;     If e = 0 and s != 0 then number is subnormal and actual exponent is -126
;     If e >= 1 then actual exponent is e-127 and actual significand is 1+t (implied 1. before t)
;
; In this module:
; Both B and C are used by the normalize function. B holds the rounding byte. C holds the high byte of the exponent.
; B and C is also used in fdiv to accumulate quotient bits and to track the exponent adjustment introduced by
; normalizing a subnormal divisor.
; D and E are used by the string conversion functions.

BIAS = 127
MAXDIGITS = 10

; We make a lot of assumptions about the size of Float in this module.
.assert .sizeof(Float) = 5, error
.assert .sizeof(Float::t) = 4, error
.assert .sizeof(Float::e) = 1, error

; Floating-point constants

fp_one: .byte $00, $00, $00, $00, 127
fp_ten: .byte $00, $00, $00, $20, 130

; Loads a new Float value from memory into FP0 or FP1.
; AY = a pointer to the value to load
; X = either #FP0 or #FP1

; Y indexes Float starting at position 0 so make sure everything is in the right place.
.assert Float::t = 0, error
.assert Float::e = 4, error

load_fp1:
        ldx     #FP1
        bne     load_fp
load_fp0:
        ldx     #FP0
load_fp:
        stay    BC                      ; FP value address into BC
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
        lda     #1                      ; Exponent is -126 (+BIAS = 1)
        sta     UnpackedFloat::e,x      ; Store exponent
        rts

; Stores the value in FP0 as a Float value in memory.
; AY = destination address

store_fp0:
        ldx     #FP0
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
; X = either #FP1t, #FPX

copy_significand_fp0_fp:
        lda     FP0t
        sta     0,x
        lda     FP0t+1
        sta     1,x
        lda     FP0t+2
        sta     2,x
        lda     FP0t+3
        sta     3,x
        rts

; Sets FP0 to zero.

clear_fp0:
        ldx     #FP0
        lda     #0
        sta     UnpackedFloat::e,x
        sta     UnpackedFloat::s,x

; Fall through

; Clears the significand of FP0 or FP1, or FPX.
; X = either #FP0t, #FP1t, #FPX
; Returns 0 in A.

clear_significand_fp:
        lda     #0
        sta     0,x
        sta     1,x
        sta     2,x
        sta     3,x
        rts

; Checks if FP0 or FP1 is zero.
; Returns with the zero flag set and 0 in A if zero, otherwise the zero flag will be clear.
; X = either #FP0 or #FP1

fp1_is_zero:
        ldx     #FP1
        bne     fp_is_zero
fp0_is_zero:
        ldx     #FP0
fp_is_zero:
        lda     UnpackedFloat::t,x      ; OR all the significand bytes together
        ora     UnpackedFloat::t+1,x
        ora     UnpackedFloat::t+2,x
        ora     UnpackedFloat::t+3,x
        rts

; Generates the two's complement of the FP0 extended significand by subtracting it from 0.
; If calling the negate_significand_16 entry point, which only affects the 2 most significant bytes,
; ensure the carry is set. 
; X SAFE, Y SAFE, BC SAFE, DE SAFE

negate_significand:
        sec
        lda     #0
        sbc     FP0t
        sta     FP0t
        lda     #0
        sbc     FP0t+1
        sta     FP0t+1
negate_significand_16:
        lda     #0
        sbc     FP0t+2
        sta     FP0t+2
        lda     #0
        sbc     FP0t+3
        sta     FP0t+3
        lda     #0
        sbc     FPX
        sta     FPX
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
        lda     FPX                     ; Extended significand
        adc     #0                      ; Extended significand of FP1 is always 0
        sta     FPX
        rts

; Utility function to shift the FP0 significand right by one bit.

shift_right:
        clc
shift_right_from_carry:
        ror     FP0t+3
        ror     FP0t+2
        ror     FP0t+1
        ror     FP0t
        rts

; Utility function to shift the FP0 significand left by one bit.

shift_left:
        clc
shift_left_from_carry:
        rol     FP0t
        rol     FP0t+1
        rol     FP0t+2
        rol     FP0t+3
        rts

; Multiplies the FP0 significand by 10. Copies the FP0 value into FP1.
; On return the carry will be set if the multiplication caused an overflow.
; On overflow, the original value can be recovered from FP1.
; Y SAFE, BC SAFE, DE SAFE

mul10_significand:
        ldx     #FP1t
        jsr     copy_significand_fp0_fp
        jsr     shift_left              ; *2
        bcs     @overflow
        jsr     shift_left_from_carry   ; *4
        bcs     @overflow
        jsr     add_significands        ; *5
        bcs     @overflow
        jsr     shift_left_from_carry   ; *10
@overflow:
        rts

; Divides the FP0 significand by 10.
; Returns the remainder in A.
; Uses X to keep track of the shift count.
; Y SAFE, BC SAFE, DE SAFE

div10_significand:
        lda     #0                      ; Initialize remainder to 0
        ldx     #32                     ; 32 bits
@next_bit:
        jsr     shift_left              ; LSB of FP0 significand is now 0
        rol     A                       ; Bits from significand move into A
        cmp     #10                     ; C ("don't borrow") set if A>=10
        bcc     @not_10                 ; It's <10
        inc     FP0t                    ; Increment quotient
        sbc     #10                     ; C will still be set here
@not_10:
        dex
        bne     @next_bit               ; More bits to shift
        rts

; Accepts a 16-bit int in AX and converts it into a float in FP0.
; AX = the input value
; DE SAFE

int_to_fp:
        sta     FP0t+2                  ; Low byte
        txa                             ; Move high byte into A
        sta     FP0t+3
        and     #$80                    ; Isolate and store sign bit
        sta     FP0s
        bpl     @positive               ; Flags set by AND
        sec                             ; Necessary for negate_significand_16
        jsr     negate_significand_16
@positive:
        mva     #0, FP0t                ; Clear two low bytes
        sta     FP0t+1
        lda     #142                    ; Starting exponent = 15
        bne     int_to_fp_common        ; Unconditional
        
; Assumes that the 32-bit value in the FP0 signifcand is an integer and converts it to a float.

int32_to_fp:
        lda     #158                    ; Starting exponent = 31

; Performs the part of integer to float conversion common to 16- and 32-bit cases:
; clear B, C, and FPX, and normalize.

int_to_fp_common:
        sta     FP0e                    ; Starting exponent
        mva     #0, C                   ; Set exponent high byte to 0
        sta     B                       ; Set round register to 0
        sta     FPX                     ; Clear low byte of extended significand
        jmp     normalize     

; Truncates the FP value to a 16-bit integer and returns it in AX.

truncate_fp_to_int:
        lda     #143                    ; Target exponent is 15, but int_to_fp_common requires target+1
        jsr     truncate_fp_to_int_common
        bcs     @error                  ; Value was too large
        lda     FP0s                    ; Was float value negative?
        bpl     @positive
        sec                             ; Necessary for negate_significand_16
        jsr     negate_significand_16
@positive:
        lda     FP0t+2                  ; Load return value into AX
        ldx     FP0t+3
        clc                             ; Signal success
@error:
        rts

; Truncates the FP value to a 32-bit integer and leaves it in the FP0 significand field.
; To generate the integer value we shift the significand (and adjust the exponent) until the exponent is 0; the
; integer part will now be to the left of the binary point. But because that would push the integer part off the
; left end of the significand field, instead we adjust until the exponent is 31, at which point the integer value
; will be in the significand field of FP0.

truncate_fp_to_int32:
        lda     #159                    ; Target exponent value is 31, but int_to_fp_common requires target+1

; Performs the part of float to integer conversion common to 16- and 32-bit cases:
; adjusts the significand right to reach a target exponent value.
; A = the target exponent value *plus one* (with bias)

truncate_fp_to_int_common:
        eor     #$FF                    ; A = (-(target+1)) - 1
        sec                             ; Set carry to ADC completes the two's complement operation
        adc     FP0e                    ; A = exponent - (target+1)
        tay                             ; A = -(number of shifts) - 1, so we pre-increment and check for 0
        bcc     @decrement              ; If we borrowed to subtract target+1, then E < target+1 or E <= target; ok!
        rts                             ; Otherwise return with carry set

@shift:
        jsr     shift_right             ; Shift right
@decrement:
        iny                             ; For example if E was 158 then A = (158-159) = -1, so INY gives 0 and we stop
        bne     @shift                  ; If not 0 then continue
        clc                             ; Signal success
        rts

; Converts FP number in FP0 into a string.
; Writes the string to buffer at the position specified by buffer_pos. Does not perform any error checking; there must 
; be enough space in the buffer for the write to succeed.
; buffer_pos = the write position in buffer

string_max: .byte $00, $00, $00, $00, 159       ; 2^32     (4,294,967,296  )
string_min: .byte $CC, $CC, $CC, $4C, 155       ; 2^32/10  (  429,496,729.6)

fp_to_string:
        lda     FP0s                    ; Check for negative value
        bpl     @positive               ; Nope
        ldx     buffer_pos              ; Write index
        lda     #'-'                    ; Minus sign
        sta     buffer,x
        inc     buffer_pos              ; Update index

; Handle 0 as a special case.
; The number is 0 if the significand is zero regardless of exponent.

@positive:
        mva     #0, E                   ; E keeps track of how much we have scaled up or down
        sta     FP0s                    ; Also set sign to positive since we already printed '-'
        jsr     fp0_is_zero
        bne     @maybe_scale_up
        ldx     buffer_pos              ; Write index
        lda     #'0'
        sta     buffer,x
        inc     buffer_pos              ; Update index
        rts

@scale_up:
        lday    #fp_ten
        jsr     fmul                    ; Multiply FP0 by 10
        dec     E                       ; Have to divide by 10 to get back to original number
@maybe_scale_up:
        lday    #string_min             ; Load minimum value
        jsr     fcmp                    ; Carry clear (borrow set) means FP0 < FP1 so we have to scale up
        bcc     @scale_up
        bcs     @maybe_scale_down       ; Unconditional skip past scale down code
@scale_down:
        lday    #fp_ten
        jsr     fdiv                    ; Divide FP0 by 10
        inc     E                       ; Have to multiply by 10 to get back to original number
@maybe_scale_down:
        lday    #string_max             ; Load maximum value
        jsr     fcmp                    ; Carry set (borrow clear) means FP0 >= FP1 so we have to scale down
        bcs     @scale_down
        jsr     truncate_fp_to_int32    ; Make into a 32-bit integer
        mva     #0, D                   ; D is the number of generated digits
        jsr     generate_digits

; There are D generated digits.
; The adjustment factor is 10^E, that is, current number * 10^E = original number.
;   * If E >= 0 then print D digits, E extra 0s at the end; length = D + E
;   * If -E < D then print D - (-E) digits, '.', -E digits
;   * If -E >= -D (i.e., D - (-E) <= 0) then print '0.', -(D - (-E)) 0s, then D digits

@output:
        clc                             ; It will be convenient for carry to be clear shortly
        ldx     buffer_pos              ; Load buffer position into X
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
        stx     buffer_pos
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
        ldy     D                       ; Output the remaining digits
        dey                             ; Minus one for the first digit
        beq     @skip_decimal           ; If no digits after decimal, skip the decimal
        lda     #'.'                    ; Output decimal point
        sta     buffer,x
        inx
@skip_decimal:
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
        stx     buffer_pos              ; generate_digits will clobber X so save it
        jsr     generate_digits
        ldx     buffer_pos              ; Recover X
        ldy     D
        jsr     output_y_digits
        ldy     E
        jsr     output_y_zeros
        jmp     @done        

; Generate digits. Repeatedly divide FP0 by 10, generate remainder in A.
; Will always generate at least one digit, which cannot be zero because we
; handled zero above.
; Ignore any initial zeros and increment E instead.

generate_digits:
        plstaa  BC                      ; Save return address
@next_digit:
        jsr     fp0_is_zero             ; Check if FP0 significand zero; this will never be true the first time
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

; Converts a string from the buffer into an FP number in FP0.
; If the first character is not a number or a +/-, then return an error. Otherwise, read up to the first non-digit.
; The caller should skip whitespace (if necessary) before calling this function.
; AX = the buffer address (stored in src_ptr)
; Y = the starting offset
; Returns the number in FP0 and the last read position in Y, carry clear if ok, carry set if error.

string_to_fp:
        stax    src_ptr                 ; Store src_ptr
        sty     E                       ; Save starting position in E        
        jsr     clear_fp0               ; Reset to zero (including sign)
        mva     #$80, D                 ; D counts digits after '.'; starts at -128 and jumps to 0 on '.'
        lda     (src_ptr),y
        cmp     #'-'                    ; Check if it's negative
        bne     @not_negative
        ror     FP0s                    ; If equal then carry will have been set; roll into sign
@next_character:
        iny                             ; Skip past negative sign
@not_negative:
        lda     (src_ptr),y             ; Get the next character
        cmp     #'.'                    ; Is it the decimal point?
        bne     @not_decimal_point      ; No
        lda     D                       ; Check if we've already seen a decimal
        bpl     @err_multiple_decimals
        mva     #0, D                   ; Set D to 0 to count digits after '.'
        beq     @next_character         ; Unconditional

@not_decimal_point:
        cmp     #'E'                    ; Is it 'E'?
        bne     @not_e                  ; No
        clc                             ; Signal success
        rts

@not_e:
        jsr     char_to_digit           ; Try to make it into a digit
        bcs     @not_digit              ; Character was not a digit, '.', or 'E'
        
; Multiply FP0 by 10 and add in new digit.

        pha                             ; Park digit on stack
        jsr     mul10_significand
        pla                             ; Recover digit from stack (does not affect carry)
        bcs     @err_overflow
        inc     D                       ; Increment digits after '.'
        adc     FP0t                    ; Add digit to LSB (carry will be clear)
        sta     FP0t
        bcc     @next_character         ; If no carry then next character
        inc     FP0t+1                  ; Otherwise increment next byte
        bne     @next_character         ; etc,
        inc     FP0t+2
        bne     @next_character
        inc     FP0t+3
        bne     @next_character         ; If the last byte wrapped to zero then overflow

@err_multiple_decimals:
@err_overflow:
@err_not_digit:
        ldy     E                       ; Reset position to start for return
        sec                             ; Signal error
        rts

@not_digit:
        lda     D                       ; Has D changed at all?
        cmp     #$80                    
        beq     @err_not_digit          ; No, so this is an error: we wanted a number and didn't find one

; There was at least one digit character followed by a non-digit character that isn't E, so treat this as
; the end of the number. The number is now a 32-bit integer in FP0, so convert it into FP.

        sty     E                       ; Y points to the first non-digit; save in E
        jsr     int32_to_fp
        lda     D                       ; Test number of digits
        bmi     @whole                  ; If negative or zero then no decimal point or no digits after it
        beq     @whole
        phzp    FP0, .sizeof(UnpackedFloat)     ; Hold FP0 result on stack
        lday    #fp_ten
        jsr     load_fp0                ; Set FP0 to 10
@scale_divisor:
        dec     D                       ; Decrement number of digits after decimal
        beq     @scale
        lday    #fp_ten
        jsr     fmul                    ; Multiply FP0 by 10
        jmp     @scale_divisor          ; Do it again until E is 0

@scale:
        jsr     copy_fp0_fp1            ; Move divisor into FP1
        plzp    FP0, .sizeof(UnpackedFloat)     ; Reload result saved earlier
        jsr     fdiv_fp1                ; Divide

@whole:
        ldy     E                       ; Return buffer read position in Y
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

; Adjusts the 16-bit unsigned biased exponent of FP0 (zero-extended to C) by first adding the value in X
; and then subtracting the value in Y.

adjust_exponent:
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
        lsr     FPX                     ; Shift FPX right
        jsr     shift_right_from_carry  ; Shift the remaining 32 bits; output in carry
        ror     B                       ; Rotate carry into rounding register
        inc     FP0e                    ; Increase exponent
        bne     normalize               ; Skip increment of exponent high byte FP0e did not roll over
        inc     C                       ; Increment high byte

; Fall through

; Normalizes the value in FP0. Normalization shifts the FP0 significand (adjusting the exponent each time)
; until the most-significant bit is 1. The normalize function acts on the 40-bit FP0 extended significand and
; normalizes to the 32-bit FP0 significand.
; Normalization handles several different cases:
;   * If FPX (the high byte of the 40-bit significand) has a value (if the significand is >=2),
;   then shift right (increase exponent) until the value fits into the 32-bit significand. This may happen if an
;   addition or subtraction overflowed the 32-bit significand.
;   * If the biased exponent is <-31, then return zero. This is an underflow condition; we cannot bring the exponent
;   within range without shifting all the bits of the exponent away.
;   * If the biased exponent is <1, then shift right (increase exponent) until it is 1.
;   * If the 32-bit significand, and the round register B, are zero, then return zero. This avoids fruitlessly
;   shifting left in search of a 1 to put in the most-significant bit.
;   * Shift left (decrease exponent) until a 1 bit is in the most-significant bit of the significand, or the exponent
;   reaches -126.
;   * If the value in the rounding register B is >=128 (MSB is set), then add 1 to the significand.
;   * If adding 1 to the significand for rounding caused the significand to increase to be >=2, then shift right
;   (increase exponent) once again.
;   * If the exponent is >127, fail with an overflow error.n (TODO: need to handle this)
; Otherwise, return the final result.
; This function uses and clobbers all registers, which means that any function that calls it (fadd, fsub, fmul, fdiv,
; etc.) also clobbers all registers.

normalize:

; First check if there are any bits set in the low byte of FPX, indicating the significand is >= 2.

        lda     FPX                     ; Check first extension byte
        bne     shift_right_normalize   ; There are significant bits, so shift right and try again

; Entry point if the significand fits within 32 bits.
; Check if the biased exponent is <1.

        lda     C                       ; High byte of exponent
        bmi     shift_right_normalize   ; It's negative so definitely too low
        lda     FP0e                    ; Not negative, but exponent might still be zero
        beq     shift_right_normalize

; Check if FP0 is zero. If so then set exponent to lowset possible value and return. If FP0 is not zero then it
; means that left normalization is guaranteed to end, since one of the significand bits must be 1.

@check_zero:
        jsr     fp0_is_zero             ; Check if FP0 is zero
        bne     @coarse
        ldx     B                       ; Check round
        bne     @coarse                 ; Round is not zero so we can still find a 1 bit somewhere
        lda     #1                      ; It's really zero; set lowest possible exponent and return
        sta     FP0e
        clc                             ; Signal success
        rts

@coarse:
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
        jsr     shift_left_from_carry
        dec     FP0e

@fine:
        lda     FP0t+3                  ; Get the high byte of significand
        bmi     @round                  ; Significand is normalized
        lda     FP0e                    ; Get exponent
        cmp     #1                      ; Make sure not already minimum value (-126)
        bne     @fine_shift             ; Okay to shift; otherwise leave as subnormal and fall through

; Round the result, which will possibly require another right shift.

@round:
        asl     B                       ; Shift rounding register high bit into carry
        bcc     @done                   ; If nothing there then no rounding, otherwise round away from zero
        ldx     #FP1t
        jsr     clear_significand_fp
        sta     B                       ; Also clear rounding register since it has been used to round up
        jsr     add_significands_with_carry
        beq     @done                   ; If the value written to FPX was 0 then all done
        sec                             ; Only 1 bit can possibly in FPX, so don't need to shift FPX
        jsr     shift_right_from_carry  ; Otherwise have to shift right again
        inc     FP0e                    ; Increase exponent

@done:
        clc                             ; Signal success
        rts

; Adds the value referenced by the pointer AY to FP0, leaving the sum in FP0 and possibly modifying FP1.
; AY = pointer to the value

fadd:
        jsr     load_fp1
fadd_fp1:
        mva     #0, B                   ; Initialize the rounding register to 0
        sta     C                       ; Clear the extended exponent register
        sta     FPX                     ; Also clear FP0 extended significand
        lda     FP1e                    ; FP1 exponent
        sec
        sbc     FP0e                    ; Compare exponents: FP1e - FP0e
        beq     @equal_exponents        ; Exponents are equal, just go ahead to addition
        bcc     @swap                   ; If borrow then FP0e is larger, so swap and try again
        bmi     @return_larger          ; Exponent difference >127 so addition has no effect
        tax                             ; Exponent difference is in X and is >=0

; FP0 exponent is less than FP1 exponent, so shift FP0 significand right X places to align binary points.

@align:
        jsr     shift_right
        ror     B                       ; Rotate carry into rounding register
        inc     FP0e
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

@swap:
        jsr     swap_fp0_fp1            ; Swap FP0 and FP1 in order to get value with larger exponent in FP0
        jmp     fadd_fp1

; The difference between exponents is >127, so just return the larger number (identified by N flag).

@return_larger:
        jsr     swap_fp0_fp1            ; Otherwise swap
        jmp     @finish

; Subtracts the value referenced by the pointer AY from FP0.
; AY = pointer to the value

fsub:
        jsr     load_fp1
        lda     FP1s
        eor     #$80
        sta     FP1s
        jmp     fadd_fp1

; Multiplies FP0 by the value referenced by the pointer AY, leaving the normalized result in FP0.
; AY = pointer to the value

fmul:
        jsr     load_fp1
        jsr     fp0_is_zero             ; Is FP0 zero?
        beq     @return_zero            ; Yes, just return
        jsr     fp1_is_zero             ; Test FP1
        bne     @do_multiply
@return_zero:
        jsr     clear_fp0               ; Return zero
        clc                             ; Signal success
        rts

@do_multiply:

; Do 32 bit multiplication of FP0 and FP1 significands.

        ldx     #FPX                    ; Clear the extended significand of FP0
        jsr     clear_significand_fp
        ldy     #32                     ; 32 multiplication cycles

@next_bit:
        lda     FP0t                    ; Test the least significant bit of FP0
        lsr     A                       ; Shift into carry
        bcc     @skip_add               ; FP0 LSB was 0 so don't need to add anything
        clc                             ; Add significand in FP1 to FPX
        lda     FPX
        adc     FP1
        sta     FPX
        lda     FPX+1
        adc     FP1+1
        sta     FPX+1
        lda     FPX+2
        adc     FP1+2
        sta     FPX+2
        lda     FPX+3
        adc     FP1+3                   ; This will never overflow because high bit of FPX will always be zero
        sta     FPX+3
@skip_add:
        ror     FPX+3                   ; 64-bit right shift; rotate moves carry from add into high bit
        ror     FPX+2
        ror     FPX+1
        ror     FPX
        ror     FP0t+3
        ror     FP0t+2
        ror     FP0t+1
        ror     FP0t
        dey                             ; Done with one cycle
        bne     @next_bit

; The 64-bit product in FP0t and FPX is in the range 0 to almost 4, and the binary point is between
; bits 61 and 62 (assuming MSB is 63). Use byte copy to shift it 32 places into FP0t with the next-lower byte in
; the rounding register.

        lda     FP0t+3                  ; Bits 24-31 go into rounding register
        sta     B
        lda     FPX+3
        sta     FP0t+3
        lda     FPX+2
        sta     FP0t+2
        lda     FPX+1
        sta     FP0t+1
        lda     FPX
        sta     FP0t
        mva     #0, FPX                 ; Clear extended significand

; Calculate exponent and sign.

        ldx     FP1e                    ; Add FP1e to FP0e
        ldy     #BIAS                   ; Subtract bias
        jsr     adjust_exponent         ; Do the math stuff; C is high byte of exponent
        inc     FP0e                    ; Account for the binary point being off by 1
        lda     FP0s                    ; Get sign of FP0
        eor     FP1s                    ; If both are pos or neg, then pos, else neg
        sta     FP0s
        jmp     normalize               ; Normalize and return

; Divides FP0 by the value referenced by the pointer AY, returning the quotient in FP0.
; AY = pointer to the value

fdiv:
        jsr     load_fp1
fdiv_fp1:
        jsr     fp0_is_zero             ; Is FP0 zero?
        beq     @return_zero            ; Yes, just return
        jsr     fp1_is_zero             ; Test FP1
        bne     @initalize
        sec                             ; Error if FP1 is zero
        rts

@return_zero:
        jsr     clear_fp0               ; Return zero
        clc                             ; Signal success
        rts

@initalize:
        ldx     #FPX                    ; Copy significand into FPX so we can use FP0 to build quotient
        jsr     copy_significand_fp0_fp
        mva     #0, D                   ; Extended significand of FPX will be in D
        mva     #BIAS, C                ; C keeps track of how much bias to add

; We have to shift the dividend right one place in order to ensure that it is smaller than the divisor. This means
; we'd have to shift the least-significant bit into some other location (presumably B). But the very first thing we
; do in the @divide subfunction is shift the dividend left one place. So instead of shifting right into B and then
; having to shift B left, we just don't shift anything and, the first time through, JSR to a point in @divide after the
; shift left.

        mva     #1, B                   ; Set B to 1 in order to generate 8 quotient bits
        jsr     @divide_skip_shift
        ldx     #3                      ; Store this value FP0 position 3
        bne     @store_quotient         ; Unconditional

@next_quotient_byte:
        mva     #1, B                   ; 8 more quotient bits
        jsr     @divide                 ; Call divide function; next 8 bits of quotient bits now in B
@store_quotient:
        lda     B                       ; Get quotient byte
        sta     FP0,x
        dex
        bpl     @next_quotient_byte     ; If X is still >= 0 then more bytes to do
        mva     #32, B                  ; Set B to 32 to generate 3 more quotient bits and leave them in B
        jsr     @divide
        lsr     B                       ; Need to shift them left 5; easier to roll right 4 through carry
        ror     B
        ror     B
        ror     B

; Calculate exponent and sign.

        ldy     FP1e                    ; Subtract FP1e from FP0e
        ldx     C                       ; Add bias
        jsr     adjust_exponent         ; Do the math stuff; C is high byte of exponent
        lda     FP0s                    ; Get sign of FP0
        eor     FP1s                    ; If both are pos or neg, then pos, else neg
        sta     FP0s
        mva     #0, FPX                 ; Clear FPX, which normalize will use as the extended significand
        jmp     normalize               ; Normalize and return

; Compare the dividend in FPX (plus the low byte of D) to the divisor FP1.
; If divisor is <= than dividend, shift a 1 bit into quotient byte in B, else shift a 0. Do this until a 1 bit rotates
; out of B. The value of B on entry determines how many times this function will carry out this operation. If it is
; initialized to 1, then it will loop 8 times.

@divide:
        asl     FPX                     ; Shift dividend left one bit
        rol     FPX+1
        rol     FPX+2
        rol     FPX+3
        rol     D
@divide_skip_shift:
        sec                             ; If FPX is >0 then divisor FP1 <= dividend FPX so we want carry to be set
        lda     D                       ; Dividend extended significand
        bne     @compare_done
        lda     FPX+3
        cmp     FP1t+3                  ; Sets carry (clears borrow) if divisor FP1 <= dividend FPX
        bne     @compare_done           ; If not equal then result is in carry; if equal then check next byte, etc.
        lda     FPX+2
        cmp     FP1t+2
        bne     @compare_done
        lda     FPX+1
        cmp     FP1t+1
        bne     @compare_done
        lda     FPX
        cmp     FP1t
@compare_done:
        bcc     @skip_subtract          ; If carry clear (borrow set) then divisor > dividend; don't subtract
        lda     FPX
        sbc     FP1t
        sta     FPX
        lda     FPX+1
        sbc     FP1t+1
        sta     FPX+1
        lda     FPX+2
        sbc     FP1t+2
        sta     FPX+2
        lda     FPX+3
        sbc     FP1t+3
        sta     FPX+3
        lda     D                       ; Possibly have to borrow from extended significand
        sbc     #0                      ; SBC #0 will always leave carry set
        sta     D
@skip_subtract:
        rol     B                       ; Roll the carry left into quotient
        bcc     @divide                 ; Continue if 1 bit has not emerged from B
        rts

; Negates the sign of FP0.

fneg:
        lda     FP0s
        eor     #$80
        sta     FP0s
        rts

; Compares FP0 with the value referenced by the pointer AY.
; Returns flags in the same manner as the CMP instruction: zero flag is set if numbers are equal and carry set if
; FP0 >= FP1 (or carry clear if FP0 < FP1).
; AY = pointer to the value

fcmp:
        jsr     load_fp1        
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
