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

MAXDIGITS = 10

.zeropage

; We make a lot of assumptions about the size of Float in this module.
.assert .sizeof(Float) = 5, error
.assert .sizeof(Float::t) = 4, error
.assert .sizeof(Float::e) = 1, error

; FP accumulator + extended significand
FPA: .res .sizeof(Float) + 4
; Secondary FP register
FPB: .res .sizeof(Float)

FP0: .res .sizeof(UnpackedFloat)
FP0t = FP0+UnpackedFloat::t
FP0e = FP0+UnpackedFloat::e
FP0s = FP0+UnpackedFloat::s
FP0x: .res .sizeof(UnpackedFloat::t)
FP1: .res .sizeof(UnpackedFloat)
FP1t = FP1+UnpackedFloat::t
FP1e = FP1+UnpackedFloat::e
FP1s = FP1+UnpackedFloat::s
FP2t: .res .sizeof(UnpackedFloat::t)
GRS: .res 1

; fp_ptr holds a pointer to the other argument in two-float operations
fp_ptr: .res 2

.code

; Loads FP value into FPA.
; AX = address of the value to load
; Uses Y but does not use X after the _ptr entry point.
; BC SAFE, DE SAFE

load_fpa:
        stax    fp_ptr                  ; FP value address into fp_ptr
load_fpa_with_ptr:                      ; Entry point if fp_ptr is already set
        ldy     #4                      ; Counts down from 4 to 0 for 5 bytes total
@next_byte:
        lda     (fp_ptr),y
        sta     FPA,y
        dey                             ; Decrement byte counter
        bpl     @next_byte              ; Continue if it hasn't rolled over
        rts

; Stores FP value from FPA into memory.
; AX = destination address
; Uses Y but does not use X after the _ptr1 entry point.
; BC SAFE, DE SAFE

store_fpa:
        stax    fp_ptr                  ; FP value address into fp_ptr
store_fpa_with_ptr:                     ; Entry point if fp_ptr is already set
        ldy     #4
@next_byte:
        lda     FPA,y
        sta     (fp_ptr),y
        dey                             ; Decrement byte counter
        bpl     @next_byte              ; Continue if it hasn't rolled over
        rts

; Stores 0 into FPA.
; X SAFE, Y SAFE, BC SAFE, DE SAFE

clear_fpa:
        lda     #0
        sta     FPA+Float::e
        sta     FPA+Float::t
        sta     FPA+Float::t+1
        sta     FPA+Float::t+2
        sta     FPA+Float::t+3
        rts

; Swaps FPA with a value in memory.
; AX = the address of the value in memory
; BC SAFE, DE SAFE

swap_fpa:
        stax    fp_ptr
swap_fpa_with_ptr:
        ldy     #4                      ; Y goes from 4 -> 0
@next_byte:
        ldx     FPA,y                   ; Swap one byte
        lda     (fp_ptr),y
        sta     FPA,y                   ; Uses nnnn,y addressing but no way to avoid
        txa
        sta     (fp_ptr),y
        dey
        bpl     @next_byte              ; Continue if it hasn't rolled over
        rts

; Copies FPA to FPB.
; No return value.
; X SAFE, Y SAFE, BC SAFE, DE SAFE

copy_fpa_to_fpb:
        lda     FPA+Float::e
        sta     FPB+Float::e
copy_fpa_significand_to_fpb:
        lda     FPA+Float::t
        sta     FPB+Float::t
        lda     FPA+Float::t+1
        sta     FPB+Float::t+1
        lda     FPA+Float::t+2
        sta     FPB+Float::t+2
        lda     FPA+Float::t+3
        sta     FPB+Float::t+3
        rts

; Copies FPB to FPA.
; No return value.
; X SAFE, Y SAFE, BC SAFE, DE SAFE

copy_fpb_to_fpa:
        lda     FPB+Float::e
        sta     FPA+Float::e
copy_fpb_significand_to_fpa:
        lda     FPB+Float::t
        sta     FPA+Float::t
        lda     FPB+Float::t+1
        sta     FPA+Float::t+1
        lda     FPB+Float::t+2
        sta     FPA+Float::t+2
        lda     FPB+Float::t+3
        sta     FPA+Float::t+3
        rts

; Checks if FPA is zero.
; FPA is zero if the significand is zero.
; On return, the Z flag will indicate whether FPA is zero. If FPA is zero, A will also be zero.
; X SAFE, Y SAFE, BC SAFE, DE SAFE

fpa_is_zero:
        lda     FPA+Float::t
        ora     FPA+Float::t+1
        ora     FPA+Float::t+2
        ora     FPA+Float::t+3
        rts

; Multiplies the FPA significand by 10. Copies the FPA value into FPB.
; On return the carry will be set if the multiplication caused an overflow.
; On overflow, the original value can be recovered from FPB.
; X SAFE, Y SAFE, BC SAFE, DE SAFE

significand_mul_10:
        jsr     copy_fpa_significand_to_fpb
        jsr     @shift_significand      ; *2
        bcs     @overflow
        jsr     @shift_significand      ; *4
        bcs     @overflow
        jsr     @add_significands       ; *5
        bcs     @overflow
        jsr     @shift_significand      ; *10
@overflow:
        lda     FPA+Float::e
        lda     FPA+Float::t
        lda     FPA+Float::t+1
        lda     FPA+Float::t+2
        lda     FPA+Float::t+3
        rts

; Shifts the signifiand of FPA left, multiplying it by 2.

@shift_significand:
        asl     FPA+Float::t
        rol     FPA+Float::t+1
        rol     FPA+Float::t+2
        rol     FPA+Float::t+3
        rts

; Adds the significand of FPX to FPA.

@add_significands:
        clc
        lda     FPA+Float::t
        adc     FPB+Float::t
        sta     FPA+Float::t
        lda     FPA+Float::t+1
        adc     FPB+Float::t+1
        sta     FPA+Float::t+1
        lda     FPA+Float::t+2
        adc     FPB+Float::t+2
        sta     FPA+Float::t+2
        lda     FPA+Float::t+3
        adc     FPB+Float::t+3
        sta     FPA+Float::t+3
        rts

; Divides the FPA significand by 10.
; Returns the remainder in A.
; Uses X to keep track of the shift count.
; Y SAFE, BC SAFE, DE SAFE

significand_div_10:
        lda     #0                      ; Initialize remainder to 0
        ldx     #32                     ; 32 bits
@next_bit:
        asl     FPA+Float::t            ; LSB of FPA+1 (least significant byte) is now 0
        rol     FPA+Float::t+1
        rol     FPA+Float::t+2
        rol     FPA+Float::t+3
        rol     A                       ; Bits from significand move into A
        cmp     #10                     ; C ("don't borrow") set if A>=10
        bcc     @not_10                 ; It's <10
        inc     FPA+Float::t            ; Increment quotient
        sbc     #10                     ; C will still be set here
@not_10:
        dex
        bne     @next_bit               ; More bits to shift
        rts

; Divides the extended FPA significand by 10.
; Identical to signficand_div_10 except the dividend is the 64-bit extended FPA register.
; Y SAFE, BC SAFE, DE SAFE

significand_div_10_ext:
        lda     #0                      ; Initialize remainder to 0
        ldx     #64                     ; 64 bits
@next_bit:
        asl     FPA+Float::t
        rol     FPA+Float::t+1
        rol     FPA+Float::t+2
        rol     FPA+Float::t+3
        rol     FPA+Float::t+4
        rol     FPA+Float::t+5
        rol     FPA+Float::t+6
        rol     FPA+Float::t+7
        rol     A               
        cmp     #10             
        bcc     @not_10         
        inc     FPA+Float::t           
        sbc     #10             
@not_10:
        dex
        bne     @next_bit       
        rts

; Negates the FPA significand if it is negative.
; Returns carry set if the significand was negative, carry clear it was not.
; BC SAFE, DE SAFE

negate_negative:
        lda     FPA+Float::t+3          ; MSB of significand
        tax                             ; Save it
        bpl     @finish
        jsr     fneg
@finish:
        txa                             ; Recover MSB before negation
        asl     A                       ; Shift 
        rts

; Negates FPA if carry is set, otherwise does nothing
; negates the significand if it was previously negative.

restore_negative:
        bcc     @skip
        jsr     fneg
@skip:
        rts

; Unconditionally negates FPA by subtracting the significand from zero.
; X SAFE, BC SAFE, DE SAFE

fneg:
        sec
        lda     #0
        tay
        sbc     FPA+1
        sta     FPA+1
        tya
        sbc     FPA+2
        sta     FPA+2
        tya
        sbc     FPA+3
        sta     FPA+3
        tya
        sbc     FPA+4
        sta     FPA+4
        rts

; Converts FP number in FPA into a string.
; Writes the string to buffer at the position specified by bp. Does not perform any error checking; there must 
; be enough space in the buffer for the write to succeed.

fp_to_string:
        ldx     bp                      ; Position in output buffer

; Handle 0 as a special case.
; The number is 0 if the significand is zero regardless of exponent.

        jsr     fpa_is_zero
        bne     @not_zero
        lda     #'0'
        sta     buffer,x
        inx
        jmp     @done

; If significand is negaitve, output a '-' and then negate the significand.

@not_zero:
        lda     FPA+Float::t+3          ; MSB of significand
        bpl     @generate_digits        ; Already positive, carry on with digits
        lda     #'-'                    ; Store '-' as first character
        sta     buffer,x
        inx
        jsr     fneg

; Generate digits. Repeatedly divide FPA by 10, generate remainder in A.
; Dividend in FPA shifts to the left, quotient shifts in from the right.
; Will always generate at least one digit, which cannot be zero because we
; handled zero above.

@generate_digits:
        ldy     #0                      ; Track number of generated digits in Y
        stx     bp                      ; Divide routine will clobber X so save it back tp bp
@next_digit:
        jsr     significand_div_10      ; The remainder in A is the digit
        clc                     
        adc     #'0'                    ; Convert to ASCII
        pha                             ; Use stack to store digits
        iny                             ; Number of generated digits += 1
        jsr     fpa_is_zero
        bne     @next_digit             ; Continue if significand != 0

; The number of digits we generated is in Y.
; If exponent is 0, then output the number as an integer.
;    Digits = Y
; If >0, then add that many '0' digits after number.
;    Digits = Y + E
;    If digits > MAXDIGITS, output in scientific notation.
; If <0, then the number will have a '.' with some digits before and after.
;    E is negative. Calculate A = Y (number of digits) + E:
;        If result is <0, print "0." then A '0' digits then generated digits.
;        If result is 0, print "0." followed by the generated digits.
;        If result is >0, print that many geneated digits, '.', remaining digits.
;    Digits = Y - min(Y + E, 0) (remember E is negative)
; If Digits>MAXDIGITS, output in scientific notation.

        ldx     bp                      ; Reload the buffer position
        lda     FPA+Float::e            ; Get exponent
        bmi     @negative_exponent
        tya                             ; Number of generated digits into A
        clc  
        adc     FPA+Float::e            ; A = Y + E digits
        cmp     #MAXDIGITS+1            ; Add 1 to make carry set indicate >MAXDIGITS instead of >=MAXDIGITS
        bcs     @scientific             ; It's over so print in scientific notation

; Simple output case for <=MAXDIGITS digits and exponent >= 0.

        jsr     output_y_digits
        ldy     FPA+Float::e            ; Positive E is number of trailing zeros (possibly zero)
        jsr     output_y_zeros
@done:
        stx     bp                      ; Update bp with new position
        rts

; Coming into here we expect Y to still have the number of generated digits.
; There are two cases we have to handle. The first case is when the decimal point is
; somewhere within the generated digits. The second case (starting at @leading_zeros)
; is when the decimal point comes before any of the generated digits.

@negative_exponent:
        tya                             ; Exponent is negative so
        clc                             ; digits to left of decimal is just 
        adc     FPA+Float::e            ; Y + E
        beq     @leading_zeros          ; Just need "0." and A is 0
        bmi     @leading_zeros          ; Need "0." plus -A more leading zeros
        sty     D                       ; Save number of digits in D
        tay                             ; Number of digits left of decimal point in Y
        eor     #$FF                    ; A is positive; negate A and add to D
        sec
        adc     D                       ; A is now number of digits minus digits left of decimal
        sta     D                       ; Save in D for later
        jsr     output_y_digits         ; Output the digits to the left of decimal
        lda     #'.'                    ; Output the decimal point
        sta     buffer,x
        inx
        ldy     D                       ; Digits to the right of the decimal point
        jsr     output_y_digits
        jsr     remove_trailing_zeros
        jmp     @done

@leading_zeros:
        eor     #$FF                    ; Negate A: A = ~A + 1
        sta     D                       ; Output this many leading zeros (possibly 0)
        inc     D                       ; Do the "+1" after saving since INC A requires a 65C02
        tya                             ; Number of digits
        sec
        adc     D                       ; Plus the number leading zeros, with carry set to add one for "0."
        cmp     #MAXDIGITS+1            ; Same trick with using MAXDIGITS+1
        bcs     @scientific
        lda     #'0'
        sta     buffer,x
        inx
        lda     #'.'
        sta     buffer,x
        inx
        sty     E                       ; Save number of digits
        ldy     D                       ; Number of leading zeros we stashed earlier
        jsr     output_y_zeros
        ldy     E                       ; Restore number of digits
        jsr     output_y_digits
        jsr     remove_trailing_zeros
        jmp     @done

; Output in scientific notation.
; First digit, '.', remaining digits, 'E', exponent
; Y is still the number of generated digits.

@scientific:
        pla                             ; Write first digit
        sta     buffer,x
        inx
        dey                             ; Decrement remaining digits
        beq     @generate_e             ; Nothing after the decimal point
        lda     #'.'                    ; Decimal point
        sta     buffer,x
        inx
        tya                             ; Increase exponent by whatever's left to print
        clc
        adc     FPA+Float::e            ; A = E + X-1
        sta     FPA+Float::e            ; Store back in FPA
        jsr     output_y_digits
        jsr     remove_trailing_zeros
        jmp     @generate_e

; Output exponent in FPA.
; Same logic as above, but only FPA is involved.

@generate_e:
        lda     #'E'
        sta     buffer,x
        inx
        lda     FPA+Float::e            ; Sets N if exponent < 0
        bpl     @e_positive
        eor     #$FF            
        sta     FPA+Float::e            ; Exponent is now positive
        inc     FPA+Float::e            ; Except not really, still have to do the +1
        lda     #'-'
        sta     buffer,x
        inx
@e_positive:
        stx     bp                      ; Save output index
        ldy     #0                      ; Again use Y to track generated digits
@e_next_digit:
        lda     #0                      ; Zero remainder
        ldx     #8                      ; 8 bits
@e_next_bit:
        asl     FPA+Float::e
        rol     A
        cmp     #10
        bcc     @e_not_10
        inc     FPA+Float::e
        sbc     #10                     ; Carry must be set here
@e_not_10:
        dex
        bne     @e_next_bit
        clc
        adc     #'0'
        pha
        iny                             ; Increment generated digits
        lda     FPA+Float::e
        bne     @e_next_digit
        ldx     bp                      ; Reload output index
        jsr     output_y_digits
        jmp     @done

; Output Y (possibly zero) digits from the stack.
; The digits are on the stack, behind the JSR return address, so we pop
; the return address off, stash it in BC, and then restore it before returning.
; X = the current buffer position (updated)
; BC SAFE

output_y_digits:
        plstaa  BC
@output_digit:
        dey
        bmi     @done
        pla
        sta     buffer,x
        inx
        bne     @output_digit           ; Unconditional

@done:
        ldphaa  BC
        rts

; Output Y (possibly zero) zero digits.
; X = the current buffer position (updated)
; BC SAFEM, DE SAFE

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

; Internal subroutine to eliminate trailing zeros after the decimal point by
; backing up X. Remember that X always points to the next position.
; X = the current buffer position

remove_trailing_zeros:
        dex                             ; Back up X by 1
        lda     buffer,x                ; See what's there
        cmp     #'0'                    ; Is it '0'?
        beq     remove_trailing_zeros   ; If yes then keep backing up
        cmp     #'.'                    ; If it's a '.' then we'll remove it too
        beq     @done                   ; Do it by just not incrementing Y
        inx                             ; Not a zero or '.''; write next charater after this one
@done:
        rts 

; Converts a string in bufer into an FP number in FPA.
; If the first character is not a number, then return an error. Otherwise, read up to the first non-digit.
; bp = the read position in buffer
; Returns the number in FPA and carry clear if ok, carry set if error.

string_to_fp:
        jsr     clear_fpa               ; Clear FPA
        ldx     bp                      ; X is the index into the string
        ldy     #$80                    ; Y counts digits after '.'; starts at -128 and jumps to 0 on '.'
        lda     buffer,x                ; Check first character
        cmp     #'-'                    ; Is the first character a minus?
        php                             ; Remember result of this for later
        bne     @bypass_increment
@next_character:
        inx                             ; Increment to the next character
@bypass_increment:
        lda     buffer,x                ; Get the next character
        cmp     #'.'                    ; Is it the decimal point?
        bne     @not_decimal_point      ; No
        tya                             ; Check if we've already seen a decimal
        bpl     @err_multiple_decimals
        ldy     #0                      ; Set Y to 0 to count digits after '.'
        jmp     @next_character

@not_decimal_point:
        jsr     char_to_digit           ; Try to make it into a digit
        bcs     @not_digit              ; Character was not a digit
        sta     D                       ; Park digit

; Multiply FPA by 10 and add in new digit.

        jsr     significand_mul_10
        bcs     @err_overflow
        iny                             ; Increment digits after '.'
        lda     D                       ; Recall the digit
        clc     
        adc     FPA+Float::t            ; Add digit to LSB
        sta     FPA+Float::t
        bcc     @next_character         ; If no carry then next character
        inc     FPA+Float::t+1          ; Otherwise increment next byte
        bne     @next_character         ; etc,
        inc     FPA+Float::t+2
        bne     @next_character
        inc     FPA+Float::t+3
        beq     @err_overflow           ; If significand rolled over to 0 then overflow
        jmp     @next_character

@not_digit:
        cpy     #$80                    ; Has Y changed at all?
        beq     @err_not_digit          ; No, so this is an error: we wanted a number and didn't find one
        lda     buffer,x                ; Load character again; -1 since we've incremented X
        cmp     #'E'                    ; Is it 'E'?
        beq     @handle_e               ; Yes

; Update the exponent and finish.

@finish:
        tya                             ; Exponent adjustment to A
        bpl     @set_exponent           ; If adjustment is positive then use it
        lda     #0                      ; Otherwise make it 0
@set_exponent:
        sta     D                       ; Use D to temporarily store adjustment
        sec
        lda     FPA+Float::e
        sbc     D
        bvs     @err_overflow           ; Adjusting E might cause signed overflow
        sta     FPA+Float::e            ; Store exponent
        plp                             ; Go get the '-' comparison from earlier
        bne     @positive               ; There was no '-' at the start of the string
        jsr     fneg
        bpl     @err_overflow_2         ; Overflow if we were expecting negative but number is positive
        bmi     @done

@positive:
        lda     FPA+Float::t+3
        bmi     @err_overflow_2         ; Overflow if we were expecting positive but number is negative
@done:
        stx     bp                      ; Update bp
        clc                             ; Signal success
        rts

@err_overflow_in_e:
        pla                             ; Errors that require two pops
@err_overflow:
@err_not_digit:
@err_multiple_decimals:
        pla                             ; Errors that require one pop
@err_overflow_2:
        sec                             ; Signal failure
        rts

; There can be 1-3 exponent digits after 'E' optionally prefixed by '-'.
; Parse the number and store in FPA exponent.
; Checks for digits also handle the case of the string ending after 'E' or '-'.

@handle_e:
        inx                             ; Skip 'E'
        lda     buffer,x                ; First character
        cmp     #'-'                    ; Is it minus?
        php                             ; Save the result for later
        bne     @bypass_increment_e
@next_character_e:
        inx                             ; Skip the minus
@bypass_increment_e:
        lda     buffer,x                ; Next character
        jsr     char_to_digit           ; Try to parse as digit
        bcs     @finish_e               ; Was not digit
        sta     D                       ; Park digit in D
        lda     FPA+Float::e            ; Get exponent
        asl     A                       ; Exponent *2
        bcs     @err_overflow_in_e
        asl     A                       ; *4
        bcs     @err_overflow_in_e
        adc     FPA+Float::e            ; *5, carry guaranteed to be clear
        bcs     @err_overflow_in_e
        asl     A                       ; *10
        bcs     @err_overflow_in_e
        adc     D                       ; Add in the new digit
        bcs     @err_overflow_in_e
        bmi     @err_overflow_in_e      ; If it goes negative then fail
        sta     FPA+Float::e
        jmp     @next_character_e

@finish_e:
        plp                             ; Get the '-' comparison from before
        bne     @finish                 ; If it wasn't negative then all done
        lda     FPA+Float::e            ; Negate exponent
        eor     #$FF
        sta     FPA+Float::e
        inc     FPA+Float::e
        jmp     @finish

; Converts the character in A into a digit.
; Returns the digit in A, carry clear if ok, carry set if error.
; X SAFE, Y SAFE, BC SAFE, DE SAFE

char_to_digit:
        sec                             ; Set carry
        sbc     #'0'                    ; Subtract '0'; maps valid values to range 0-9 and other values to 10-255
        cmp     #10                     ; Sets carry if it's in the 10-255 range
        rts

; Converts a 16-bit signed integer value into floating point value in FPA.
; A, X = 16-bit integer.
; No return value.

int_to_fp:
        sta     FPA+Float::t            ; Store low byte
        stx     FPA+Float::t+1          ; Store high byte
        txa                             ; High byte to A
        asl     A                       ; Shift sign bit into carry
        lda     #0
        sta     FPA                     ; Set exponent to 0
        adc     #$FF                    ; Carry still has sign bit; A = $FF if positive, 0 if negative
        eor     #$FF                    ; Invert bits; A is now $FF if number was negative
        sta     FPA+Float::t+2          ; Sign extend the 16-bit integer to 32-bit significand
        sta     FPA+Float::t+3
        rts

; Truncates FPA to an integer and store the result in the lower two bytes of FPA.
; FPA must be in the range -32,768 to 32,767. FPA values aren't necessarily
; normalized so we could encounter 10 as 10E+0, 1E+1, or 100E-1. First we
; adjust the exponent to 0 by dividing or multiplying by 10. It's okay if, when dividing by 10,
; we lose digits off the right since this is a truncation function. After adjusting we check
; to see if the value is in range. 

truncate_fp_to_int:

; Make the exponent 0, which will leave the integer value int the two least-significant bytes
; of the significand.

@dec_e:
        lda     FPA+Float::e            ; Test the exponent byte
        beq     @to_int                 ; E was 0, go directly to getting int
        bmi     @negative_e             ; E was negative

; E is positive.
; Adjust exponent down by multiplying significand by 10.

        jsr     significand_mul_10
        bcs     @err_out_of_range
        dec     FPA+Float::e
        bne     @dec_e
        jmp     @to_int

; Adjust exponent up by dividing by 10.
; If significand is negative then negate it first.

@negative_e:
        jsr     negate_negative         ; Negate signifiand if it's negative
        rol     E                       ; Roll the sign of the significand into E
@inc_e:
        jsr     significand_div_10
        inc     FPA+Float::e
        bne     @inc_e
        lsr     E                       ; Get the flag back into carry
        bcc     @to_int                 ; It was positive before, no change
        jsr     fneg

@to_int:
        lda     FPA+2                   ; MSB of 16-bit int value
        asl     A                       ; Sign bit into carry
        lda     #$FF
        adc     #0                      ; A is 0 if sign bit was negative, $FF if positive
        eor     #$FF                    ; Invert bits
        cmp     FPA+3                   ; 2 most significant bytes of significand must be this value
        bne     @err_out_of_range
        cmp     FPA+4  
        bne     @err_out_of_range
        lda     FPA+1                   ; Low byte
        ldx     FPA+2                   ; High byte
        clc                             ; Signal success
        rts

@err_out_of_range:
        sec                             ; Signal error
        rts

; Adds a value to FPA, returning result in FPA.
; The strategy is to get the number with the larger exponent into FPA.
; AX = pointer to the float value to add to FPA

fadd:
        stax    fp_ptr
fadd_with_ptr:
        ldy     #Float::e
        lda     (fp_ptr),y              ; Argument exponent
        sec
        sbc     FPA+Float::e            ; If N eor V then ptr1 exponent < FPA exponent
        beq     @equal_exponents        ; Exponents are equal, just go ahead to addition
        bvc     @v_clear
        eor     #$80                    ; V is 1 and A7 is N so this does N eor V
@v_clear:
        bmi     @fpa_eq_or_gt           ; If N eor V then ptr1 exponent < FPA exponent so don't swap
        jsr     swap_fpa_with_ptr       ; Swap FPA with the value (clobbers X and Y)
@fpa_eq_or_gt:
        sec                     
        lda     FPA+Float::e            ; FPA exponent is equal or greater
        ldy     #Float::e               ; so when we subtract fp_ptr exponent,
        sbc     (fp_ptr),y              ; we'll get the unsigned difference
        sta     D                       ; Park exponent differerence in D

; TODO: detect if we've reached limit of exponent range.
; TODO: detect if exponent difference is too great and just return FPA in this case.
; TODO: can probably eliminate one of these swaps, or just have a function to negate ptr1.

; Negate negative numbers before adjusting.

        jsr     negate_negative         ; Negate potentially negative FPA
        rol     E                       ; Roll the flag into E (don't care what was there before)
        jsr     swap_fpa_with_ptr       ; Swap values
        jsr     negate_negative         ; Negate potentially negative fp_ptr
        rol     E                       ; Roll the flag into E
        jsr     swap_fpa_with_ptr       ; Restore FPA and ptr1
        ldx     D                       ; Use X to track the exponent difference

; Try to make the greater exponent of FPA equal to the exponent of FPX by multiplying it by 10.
; Stop either when the exponents are equal or when the multiplication overflows.

@grow:
        jsr     significand_mul_10      ; Trial multiplication by 10
        bcs     @fpa_overflow           ; Can't do this anymore, FPA overflowed
        bmi     @fpa_overflow           ; Or it went negative
        dec     FPA+Float::e            ; It worked so decrement exponent and X and try again                     
        dex                      
        bne     @grow
        beq     @restore_significands   ; Unconditional

; We can't equalize exponents by multiplying FPA, so now we have to divide the other value, which will result in
; some loss of precision. We have to swap the arguments temporarily here because we can only divide FPA.

@fpa_overflow:
        jsr     copy_fpb_significand_to_fpa ; Recover saved significand from FPX
        jsr     swap_fpa_with_ptr
@shrink:
        jsr     significand_div_10      ; Divide FPA by 10
        inc     FPA+Float::e            ; Increment exponent
        dex                             ; Close the exponent gap
        bne     @shrink                 ; Still more to do        
        jsr     swap_fpa_with_ptr       ; Swap back before continuing

@restore_significands:
        jsr     swap_fpa_with_ptr       ; Move fp_ptr value back into FPA
        lsr     E                       ; Shifts negative flag from E into carry
        jsr     restore_negative
        jsr     swap_fpa_with_ptr       ; Original value back to FPA; do the same thing
        lsr     E
        jsr     restore_negative

; When both exponents are equal we can just add the significand of the value to that of FPA. 

@equal_exponents:
        ldy     #Float::t
        clc
        lda     FPA+Float::t
        adc     (fp_ptr),y              ; Add the significands
        sta     FPA+Float::t
        iny
        lda     FPA+Float::t+1
        adc     (fp_ptr),y       
        sta     FPA+Float::t+1
        iny
        lda     FPA+Float::t+2
        adc     (fp_ptr),y        
        sta     FPA+Float::t+2
        iny
        lda     FPA+Float::t+3
        adc     (fp_ptr),y        
        sta     FPA+Float::t+3

; If the addition has caused signed overflow, divide the significand by 10
; and increase the exponent.

; TODO: this doesn't work; I need to negate before dividing by 10

        bvc     @done
        jsr     significand_div_10_ext
        inc     FPA+Float::e
@done:
        rts

; Subtracts a value from FPA, returning result in FPA.
; Simply negates the value and then delegates to fadd.
; The operation is (FPA - value), but we make it -(value - FPA) in order to use the fneg function on FPA.

fsub:
        stax    fp_ptr
fsub_with_ptr:
        jsr     fneg
        jsr     fadd_with_ptr
        jmp     fneg

; Muliplies FPA by the a value, returning the result in FPA.
; Scales FPA so product fits into signficand.

; Logic that handles Y depends on exponent being 0 and significand being 1
; .assert Float::e = 0, error
; .assert Float::t = 1, error

fmul:
        stax    fp_ptr
fmul_with_ptr:
        jsr     negate_negative         ; Make both operands positive
        rol     E                       ; Roll the flag into E (don't care what was there before)
        jsr     swap_fpa_with_ptr
        jsr     negate_negative         ; Make both operands positive
        rol     E                       ; Roll the flag into E (don't care what was there before)
        jsr     swap_fpa_with_ptr       ; Restore FPA and value to original positions
        ldy     #Float::e
        lda     (fp_ptr),y              ; Load value exponent
        clc
        adc     FPA+Float::e            ; Add FPA exponent
        bvs     @err_overflow           ; If overflow then fail
        sta     FPA+Float::e            ; Store result exponent back in FPA
        jsr     mul_significands
        jsr     shrink_significand
        lda     E                       ; Bits 0-1 of E are negative flags
        lsr     A                       ; Bit 0 of A is bit 1 from E
        eor     E                       ; Effectively EORs the two bits together
        lsr     A                       ; Shift it into carry
        bcc     @positive               ; If both bits were 0 or 1 then product is positive
        jsr     fneg                    ; Product is negative
@positive:
        rts

@err_overflow:
        rts

; Multiplies the significands of FPA and fp_ptr, leaving a 64-bit result in FPA.

mul_significands:
        jsr     copy_fpa_to_fpb         ; FPA -> FPB so we can use FPA for product
        lda     #0                      ; Zero out the high 32 bits of the product
        sta     FPA+Float::t+4          
        sta     FPA+Float::t+5           
        sta     FPA+Float::t+6
        sta     FPA+Float::t+7
        ldx     #32                     ; 32 multiplication cycles
@next_bit:
        lsr     FPB+Float::t+3          ; Shift the multiplicand right
        ror     FPB+Float::t+2
        ror     FPB+Float::t+1
        ror     FPB+Float::t
        bcc     @skip                   ; Bit 0 of multiplicand was zero; don't add
        ldy     #Float::t
        clc
        lda     FPA+Float::t+4          ; Add value to high 32 bits of FPA
        adc     (fp_ptr),y
        sta     FPA+Float::t+4
        iny
        lda     FPA+Float::t+5
        adc     (fp_ptr),y
        sta     FPA+Float::t+5
        iny
        lda     FPA+Float::t+6
        adc     (fp_ptr),y
        sta     FPA+Float::t+6
        iny
        lda     FPA+Float::t+7
        adc     (fp_ptr),y
        sta     FPA+Float::t+7
@skip:
        ror     FPA+Float::t+7          ; Shift carry and 64-bit FPA significand one place to right
        ror     FPA+Float::t+6
        ror     FPA+Float::t+5
        ror     FPA+Float::t+4
        ror     FPA+Float::t+3
        ror     FPA+Float::t+2
        ror     FPA+Float::t+1
        ror     FPA+Float::t
        dex                             ; Decrement bit counter
        bne     @next_bit               ; Keep going
        rts

; Divides the 64-bit significand by 10 until it fits into 32 bits.

shrink_significand:
        lda     FPA+Float::t+4
        ora     FPA+Float::t+5
        ora     FPA+Float::t+6
        ora     FPA+Float::t+7
        beq     @done
        jsr     significand_div_10_ext
        inc     FPA                     ; Increase exponent to compensate for division
        jmp     shrink_significand

@done:
        rts

; Divides FPA by the a value, returning the quotient in FPA.
; Shifts the dividend left into the FPA extended significand. After each shift, check if it's greater than the
; dividend; if so then add one to the significand. After 32 operations, the quotient will be in the lower 32 bits
; of FPA and the remainder will be in the upper 32 bits.

; TODO: check divide by zero

fdiv:
        stax    fp_ptr
fdiv_with_ptr:
        jsr     negate_negative         ; Make both operands positive
        rol     E                       ; Roll the flag into E (don't care what was there before)
        jsr     swap_fpa_with_ptr
        jsr     negate_negative         ; Make both operands positive
        rol     E                       ; Roll the flag into E (don't care what was there before)
        jsr     swap_fpa_with_ptr       ; Restore FPA and value to original positions
@scale_up:
        lda     FPA+Float::t+3          ; Get high byte of dividend
        cmp     #6                      ; Compare to 6
        bcs     @handle_e               ; High byte is >= 6, keep it
        jsr     significand_mul_10      ; Otherwise multiply by 10
        dec     FPA+Float::e            ; and decrement exponent to offset
        jmp     @scale_up               ; Try again
@handle_e:
        jsr     swap_fpa_with_ptr       ; Swap
        jsr     copy_fpa_to_fpb         ; Copy divisor into FPB
        jsr     swap_fpa_with_ptr       ; Swap back
        lda     FPA+Float::e            ; Subtract divisor exponent from dividend exponent
        sec
        sbc     FPB+Float::e
        bvs     @err_overflow           ; If overflow then fail
        sta     FPA+Float::e            ; Save back as FPA exponent
        ldx     #32                     ; 32 bits
@next_bit:
        asl     FPA+Float::t
        rol     FPA+Float::t+1
        rol     FPA+Float::t+2
        rol     FPA+Float::t+3
        rol     FPA+Float::t+4
        rol     FPA+Float::t+5
        rol     FPA+Float::t+6
        rol     FPA+Float::t+7
        lda     FPA+Float::t+7          ; Compare FPA extended siginficand with FPB (divisor)
        cmp     FPB+Float::t+3
        bcc     @less_than_divisor
        lda     FPA+Float::t+6
        cmp     FPB+Float::t+2
        bcc     @less_than_divisor
        lda     FPA+Float::t+5
        cmp     FPB+Float::t+1
        bcc     @less_than_divisor
        lda     FPA+Float::t+4
        cmp     FPB+Float::t
        bcc     @less_than_divisor
        sec                             ; Subtract dividend in FPB from FPA extended significand
        lda     FPA+Float::t+7
        sbc     FPB+Float::t+3
        sta     FPA+Float::t+7
        lda     FPA+Float::t+6
        sbc     FPB+Float::t+2
        sta     FPA+Float::t+6
        lda     FPA+Float::t+5
        sbc     FPB+Float::t+1
        sta     FPA+Float::t+5
        lda     FPA+Float::t+4
        sbc     FPB+Float::t
        sta     FPA+Float::t+4
        inc     FPA+Float::t            ; Increment quotient
@less_than_divisor:
        dex                             ; One bit done
        bne     @next_bit               ; Continue if more
        jsr     shrink_significand
@try_make_e_positive:
        jsr     copy_fpa_to_fpb         ; Back up value in FPB
        lda     FPA+Float::e            ; Check the FPA exponent
        bpl     @finish                 ; If positive than done
        jsr     significand_div_10      ; Divide by 10
        tax                             ; Remainder is in A; update flags
        bne     @finish                 ; There is a remainder
        inc     FPA+Float::e            ; Increment exponent
        jmp     @try_make_e_positive    ; Try to get closer to 0

@finish:
        jsr     copy_fpb_to_fpa         ; Copy original value back from FPB
        lda     E                       ; Bits 0-1 of E are negative flags
        lsr     A                       ; Bit 0 of A is bit 1 from E
        eor     E                       ; Effectively EORs the two bits together
        lsr     A                       ; Shift it into carry
        bcc     @positive               ; If both bits were 0 or 1 then product is positive
        jsr     fneg                    ; Product is negative
@positive:
        rts

@err_overflow:
        rts

; Compare two floating-point values.
; Returns result in N and C flags, in the same way that the CMP instruction works.

fcmp:
        stax    fp_ptr
fcmp_with_ptr:
        jsr     fsub_with_ptr           ; Subtract the two
        sec                             ; Set carry ("no borrow") in case they're equal
        jsr     fpa_is_zero             ; Check for zero
        beq     @done
        lda     FPA+Float::t+3          ; Load high byte of significand to access sign bit
        eor     #$80                    ; Flip sign bit; if (A-B) < 0 then A < B and we return carry clear
        sec 
        rol     A                       ; Roll set carry bit into A to ensure zero flag is not set
@done:
        rts

; ---------------------------------------------------------------------------------------------------------------------

; Loads a new Float value from memory into FP0 or FP1.
; AY = a pointer to the value to load
; X = either #FP0 or #FP1

; Y indexes Float starting at position 0 so make sure everything is in the right place.
.assert Float::t = 0, error
.assert Float::e = 4, error

load_fpx:
        stay    fp_ptr                  ; Store the pointer to the new value
        ldy     #0                      ; Start with low byte of significand
        lda     (fp_ptr),y
        sta     UnpackedFloat::t,x
        iny
        lda     (fp_ptr),y
        sta     UnpackedFloat::t+1,x
        iny
        lda     (fp_ptr),y
        sta     UnpackedFloat::t+2,x
        iny
        lda     (fp_ptr),y              ; High 7 bits of significand plus sign
        and     #$80                    ; Isolate high bit
        sta     UnpackedFloat::s,x      ; Store sign (only bit 7 is signifncant)
        lda     (fp_ptr),y              ; Reload
        and     #$7F                    ; Isolate significand
        sta     UnpackedFloat::t+3,x    ; Store high 7 bits of significand
        iny     
        lda     (fp_ptr),y              ; Exponent
        beq     @subnormal_or_zero      ; Handle as subnormal; significand MSB will be 0 in this case
        eor     #$80                    ; Invert MSB
        sta     UnpackedFloat::e,x      ; Store exponent
        lda     #$80                    ; High bit of significand
        ora     UnpackedFloat::t+3,x    ; OR with high byte
        sta     UnpackedFloat::t+3,x    ; Save back
        rts

@subnormal_or_zero:
        lda     #$81                    ; Exponent is -127 ($81)
        sta     UnpackedFloat::e,x      ; Store exponent
        rts

; Stores the value in FP0 or FP1 as a Float value in memory.
; AY = destination address
; X = either #FP0 or #FP1

store_fpx:
        stay    fp_ptr                  ; FP value address into fp_ptr
        ldy     #0                      ; Start with low byte of significand
        lda     UnpackedFloat::t,x
        sta     (fp_ptr),y
        iny
        lda     UnpackedFloat::t+1,x
        sta     (fp_ptr),y
        iny
        lda     UnpackedFloat::t+2,x
        sta     (fp_ptr),y
        iny
        lda     UnpackedFloat::t+3,x    ; High byte of significand
        bpl     @subnormal_or_zero      ; MSB of significand is 0 so this is subnormal or zero
        and     #$7F                    ; Set MSB to 0
        ora     UnpackedFloat::s,x      ; OR in the sign bit
        sta     (fp_ptr),y              ; Save
        iny
        lda     UnpackedFloat::e,x
        eor     #$80                    ; Invert MSB for storage
        sta     (fp_ptr),y              ; Store
        rts

@subnormal_or_zero:
        ora     UnpackedFloat::s,x      ; OR in the sign bit
        sta     (fp_ptr),y              ; Save
        iny
        lda     #0
        sta     (fp_ptr),y              ; Exponent is zero
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

; Checks if FP0 is zero.
; Returns with the zero flag set and 0 in A if FP0 is zero, otherwise the zero flag will be clear.

fp0_is_zero:
        lda     FP0t                    ; OR all the significand bytes together
        ora     FP0t+1
        ora     FP0t+2
        ora     FP0t+3
        rts

; Assumes that the 32-bit value in the FP0 significand is an integer and converts it to a float.

int_to_fp2:
        lda     #30                     ; Have to shift this number left 30 places to get original value
        sta     FP0e
        jmp     normalize_left     

; Returns the greatest 32-bit integer less than or equal to the input value.
; To generate the integer value we shift the significand (and adjust the exponent) until the exponent is 0; the
; integer part will now be to the left of the binary point. But because that would push the integer part off the
; left end of the significand field, instead we adjust until the exponent is 30, at which point the integer value
; will be in the significand field of FP0.

truncate_fp_to_int2:
        lda     FP0e                    ; Get the exponent
        sec
        sbc     #31                     ; Target exponent value is 30, but subtract 31
        tay                             ; Otherwise A is -(number of shifts) - 1, so we pre-increment and check for 0
        bcc     @decrement              ; If we borrowed to subtract 31, then E < 31 or E <= 30; ok!
        rts                             ; Otherwise return with carry set

@shift:
        jsr     shift_right             ; Otherwise shift right
@decrement:
        iny                             ; For example if E was 30 then A = (30-31) = -1, so INY gives 0 and we stop
        bne     @shift                  ; If not 0 then continue

@return_value:
        clc                             ; Signal success
        rts

; Utility function to shift the 40-bit extended significand of FP0 right by one bit and increment exponent.
; The caller is responsible for testing for exponent overflow before calling.

shift_right:
        lsr     FP0x                    ; Right shift low byte of FP0x plus FP0t
shift_right_from_carry:
        ror     FP0t+3
        ror     FP0t+2
        ror     FP0t+1
        ror     FP0t
        inc     FP0e                    ; Increase exponent
        rts

; Returns an error to the caller.

overflow:
        sec
        rts

; Shifts the 40-bit FP0 extended significand one place to the right and re-attempts normalization.
; Invoked from normalize when the significand doesn't fit into 32 bits.

shift_right_normalize:
        lda     FP0e                    ; Check exponent for overflow
        cmp     #$7F
        beq     overflow
        jsr     shift_right             ; Use shift_right to shift the remaining 32 bits

; Fall through

; Normalizes the value in FP0. Normalization shifts the FP0 significand (adjusting the exponent each time)
; until the most-significant bit (excluding the sign bit) differs from the sign bit. The normalize function acts on
; the 40-bit FP0 extended significand and normalizes to the 32-bit FP0 significand.

normalize:

; First check if there are any bits set in the low byte of FP0x, indicating the significand is >= 2.

        lda     FP0x                    ; Check first extension byte
        bne     shift_right_normalize   ; There are significant bits, so shift right and try again

; Entry point if the significand fits within 32 bits.
; First check if FP0 is zero. If so then make exponent zero and return.
; If FP0 is not zero then it means that normalization is guaranteed to end: either the sign bit is 0, and one of
; the other significand bits is 1 (since the significand overall is not zero); or the sign bit is 1, and eventually
; we'll see a 0 bit, because we shift in 0s from the right.

normalize_left:
        jsr     fp0_is_zero             ; Check if FP0 is zero
        bne     @coarse
        sta     FP0e                    ; Make sure exponent is also zero
        rts

@coarse:
        ldy     FP0t+3                  ; Get high byte of significand
        bne     @fine                   ; If not 0 then try fine shift

; The high byte is 0, so shift left 8 bits using byte moves.

@coarse_shift:
        debug $00
        lda     FP0e                    ; Get exponent
        sec
        sbc     #8                      ; Trial subtraction of 8
        bvs     @fine                   ; If subtracting produced signed overflow then try fine shift
        cmp     #$80                    ; Check if it went to -128
        beq     @fine                   ; If so then can't apply coarse shift; do fine shift instead
        sta     FP0e                    ; Otherwise update exponent
        lda     FP0t+2
        sta     FP0t+3                  ; Store new high byte
        lda     FP0t+1                  ; Shift other bytes
        sta     FP0t+2          
        lda     FP0t
        sta     FP0t+1
        lda     #0                      ; Store 0 in last byte
        sta     FP0t
        beq     @coarse                 ; Unconditional

@fine_shift:
        debug $10
        asl     FP0t                    ; Shift left one bit
        rol     FP0t+1
        rol     FP0t+2
        rol     FP0t+3
        dec     FP0e

@fine:
        lda     FP0t+3                  ; Get the high byte of significand
        bmi     @done                   ; Significand is normalized
        lda     FP0e                    ; Get exponent
        cmp     #$81                    ; Make sure not already minimum value (-127)
        bne     @fine_shift             ; Okay to shift; otherwise fall through to underflow

@done:
        rts

swap_fadd2:
        jsr     swap_fp0_fp1            ; Swap FP0 and FP1 in order to get value with larger exponent in FP0

; Fall through

; Performs FP0 + FP1, leaving the sum in FP0 and possibly modifying FP1.

fadd2:
        mva     #0, GRS                 ; Initialize GRS to 0 (TODO: make sure we handle GRS and rounding correctly.)
        lda     FP0e                    ; FP0 exponent
        sec
        sbc     FP1e                    ; Compare exponents: FP0e - FP1e
        beq     @equal_exponents        ; Exponents are equal, just go ahead to addition
        bvs     @return_larger          ; Exponent difference >127 so addition has no effect
        bmi     swap_fadd2              ; FP1e is larger, so swap and do it again
        tax                             ; Exponent different is in X and is >0
@align:
        debug $00
        lsr     FP1+Float::t+3          ; Shift FP1 significand right
        ror     FP1+Float::t+2
        ror     FP1+Float::t+1
        ror     FP1+Float::t
        lda     GRS                     ; Get GRS
        and     #$01                    ; Isolate sticky bit
        ror     GRS                     ; Rotate carry into GRS
        ora     GRS                     ; OR with the sticky bit
        sta     GRS                     ; Store back in GRS
        inc     FP1+Float::e            ; Increment exponent
        dex
        bne     @align
@equal_exponents:
        debug $10
        clc
        lda     FP0+Float::t            ; Add the significands
        adc     FP1+Float::t
        sta     FP0+Float::t
        lda     FP0+Float::t+1
        adc     FP1+Float::t+1
        sta     FP0+Float::t+1
        lda     FP0+Float::t+2
        adc     FP1+Float::t+2
        sta     FP0+Float::t+2
        lda     FP0+Float::t+3
        adc     FP1+Float::t+3
        sta     FP0+Float::t+3
        lda     #0                      ; Extended significand
        adc     #0                      ; Do 0+0+carry
        debug $11
        sta     FP0x
        bcc     @finish                 ; Unconditional; carry will always be clear here

; The difference between exponents is >127, so just return the larger number (identified by N flag).

@return_larger:
        bmi     @finish                 ; A was larger so just return
        jsr     swap_fp0_fp1            ; Otherwise swap, then fall through to return B

; TODO: round

@finish:
        jmp     normalize               ; Normalize result and return

