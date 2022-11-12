.include "macros.inc"
.include "basic.inc"

; Floating Point Math Routines
;
; Format is 40 bits (5 bytes):
; eeeeeeee tttttttt tttttttt tttttttt tttttttt .
;
; e = exponent, 8 bits, two's complement
; t = significand, 40 bits, two's complement
; . = implied decimal point after significand
;
; Exponent range is 10^-128 to 10^127
; Significand range is -2,147,483,648 to 2,147,483,647

MAXDIGITS = 10

.zeropage

; We make a lot of assumptions about the size of Float in ths module.
.assert .sizeof(Float) = 5, error
.assert .sizeof(Float::e) = 1, error
.assert .sizeof(Float::s) = 4, error

; FP accumulator + extended significand
FPA: .res .sizeof(Float) + 4
; Secondary FP register
FPB: .res .sizeof(Float)

; fp_ptr holds a pointer to the other argument in two-float operations
fp_ptr: .res 2

.code

; Loads FP value into FPA.
; AX = address of the value to load
; Uses Y but does not use X after the _ptr entry point.

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
        sta     FPA+Float::s
        sta     FPA+Float::s+1
        sta     FPA+Float::s+2
        sta     FPA+Float::s+3
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
        lda     FPA+Float::s
        sta     FPB+Float::s
        lda     FPA+Float::s+1
        sta     FPB+Float::s+1
        lda     FPA+Float::s+2
        sta     FPB+Float::s+2
        lda     FPA+Float::s+3
        sta     FPB+Float::s+3
        rts

; Copies FPB to FPA.
; No return value.
; X SAFE, Y SAFE, BC SAFE, DE SAFE

copy_fpb_to_fpa:
        lda     FPB+Float::e
        sta     FPA+Float::e
copy_fpb_significand_to_fpa:
        lda     FPB+Float::s
        sta     FPA+Float::s
        lda     FPB+Float::s+1
        sta     FPA+Float::s+1
        lda     FPB+Float::s+2
        sta     FPA+Float::s+2
        lda     FPB+Float::s+3
        sta     FPA+Float::s+3
        rts

; Checks if FPA is zero.
; FPA is zero if the significand is zero.
; On return, the Z flag will indicate whether FPA is zero. If FPA is zero, A will also be zero.
; X SAFE, Y SAFE, BC SAFE, DE SAFE

fpa_is_zero:
        lda     FPA+Float::s
        ora     FPA+Float::s+1
        ora     FPA+Float::s+2
        ora     FPA+Float::s+3
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
        lda     FPA+Float::s
        lda     FPA+Float::s+1
        lda     FPA+Float::s+2
        lda     FPA+Float::s+3
        rts

; Shifts the signifiand of FPA left, multiplying it by 2.

@shift_significand:
        asl     FPA+Float::s
        rol     FPA+Float::s+1
        rol     FPA+Float::s+2
        rol     FPA+Float::s+3
        rts

; Adds the significand of FPX to FPA.

@add_significands:
        clc
        lda     FPA+Float::s
        adc     FPB+Float::s
        sta     FPA+Float::s
        lda     FPA+Float::s+1
        adc     FPB+Float::s+1
        sta     FPA+Float::s+1
        lda     FPA+Float::s+2
        adc     FPB+Float::s+2
        sta     FPA+Float::s+2
        lda     FPA+Float::s+3
        adc     FPB+Float::s+3
        sta     FPA+Float::s+3
        rts

; Divides the FPA significand by 10.
; Returns the remainder in A.
; Uses X to keep track of the shift count.
; Y SAFE, BC SAFE, DE SAFE

significand_div_10:
        lda     #0                      ; Initialize remainder to 0
        ldx     #32                     ; 32 bits
@next_bit:
        asl     FPA+Float::s            ; LSB of FPA+1 (least significant byte) is now 0
        rol     FPA+Float::s+1
        rol     FPA+Float::s+2
        rol     FPA+Float::s+3
        rol     A                       ; Bits from significand move into A
        cmp     #10                     ; C ("don't borrow") set if A>=10
        bcc     @not_10                 ; It's <10
        inc     FPA+Float::s            ; Increment quotient
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
        asl     FPA+Float::s
        rol     FPA+Float::s+1
        rol     FPA+Float::s+2
        rol     FPA+Float::s+3
        rol     FPA+Float::s+4
        rol     FPA+Float::s+5
        rol     FPA+Float::s+6
        rol     FPA+Float::s+7
        rol     A               
        cmp     #10             
        bcc     @not_10         
        inc     FPA+Float::s           
        sbc     #10             
@not_10:
        dex
        bne     @next_bit       
        rts

; Negates the FPA significand if it is negative.
; Returns carry set if the significand was negative, carry clear it was not.
; BC SAFE, DE SAFE

negate_negative:
        lda     FPA+Float::s+3          ; MSB of significand
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
        lda     FPA+Float::s+3          ; MSB of significand
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
        beq     @err_empty_string
        cmp     #'-'                    ; Is the first character a minus?
        php                             ; Remember result of this for later
        bne     @next_character
        inx                             ; Skip the minus
@next_character:
        lda     buffer,x                ; Get the next character
        beq     @finish                 ; It was NUL, the number is finished
        inx                             ; Advance to next position
        cmp     #'.'                    ; Is it the decimal point?
        bne     @not_decimal_point      ; No
        tya                             ; Check if we've already seen a decimal
        bpl     @err_multiple_decimals
        ldy     #0                      ; Set Y to 0 to count digits after '.'
        jmp     @next_character

@not_decimal_point:
        cmp     #'E'                    ; Is it 'E'?
        beq     @handle_e               ; Yes
        jsr     char_to_digit           ; But if not, must be a digit
        bcs     @err_not_digit          ; Character was not a digit
        sta     D                       ; Park digit

; Multiply FPA by 10 and add in new digit.

        jsr     significand_mul_10
        bcs     @err_overflow
        iny                             ; Increment digits after '.'
        lda     D                       ; Recall the digit
        clc     
        adc     FPA+Float::s            ; Add digit to LSB
        sta     FPA+Float::s
        bcc     @next_character         ; If no carry then next character
        inc     FPA+Float::s+1          ; Otherwise increment next byte
        bne     @next_character         ; etc,
        inc     FPA+Float::s+2
        bne     @next_character
        inc     FPA+Float::s+3
        beq     @err_overflow           ; If significand rolled over to 0 then overflow
        jmp     @next_character

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
        clc
        rts

@positive:
        lda     FPA+Float::s+3
        bmi     @err_overflow_2         ; Overflow if we were expecting positive but number is negative
        clc                             ; Signal success
        rts

@err_not_digit_in_e:
@err_overflow_in_e:
        pla                             ; Errors that require two pops
@err_overflow:
@err_multiple_decimals:
@err_not_digit:
        pla                             ; Errors that require one pop
@err_empty_string:
@err_overflow_2:
        sec                             ; Signal failure
        rts

; There can be 1-3 exponent digits after 'E' optionally prefixed by '-'.
; Parse the number and store in FPA exponent.
; Checks for digits also handle the case of the string ending after 'E' or '-'.

@handle_e:
        lda     buffer,x                ; First character
        cmp     #'-'                    ; Is it minus?
        php                             ; Save the result for later
        bne     @next_character_e
        inx                             ; Skip the minus
@next_character_e:
        lda     buffer,x                ; Next character
        beq     @finish_e
        inx
        jsr     char_to_digit           ; Try to parse as digit
        bcs     @err_not_digit_in_e     ; Was not digit
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
        sta     FPA
        inc     FPA
        jmp     @finish

; Converts the character in A into a digit.
; Returns the digit in A, carry clear if ok, carry set if error.
; X SAFE, Y SAFE

char_to_digit:
        sec                             ; Set carry
        sbc     #'0'                    ; Subtract '0'; maps valid values to range 0-9 and other values to 10-255
        cmp     #10                     ; Sets carry if it's in the 10-255 range
        rts

; Converts a 16-bit signed integer value into floating point value in FPA.
; A, X = 16-bit integer.
; No return value.

; _int_to_fp:
; int_to_fp:
;         sta     FPA+1                   ; Store low byte
;         stx     FPA+2                   ; Store high byte
;         txa                             ; High byte to A
;         asl     A                       ; Shift sign bit into carry
;         lda     #0
;         sta     FPA                     ; Set exponent to 0
;         adc     #$FF                    ; Carry still has sign bit; A = $FF if positive, 0 if negative
;         eor     #$FF                    ; Invert bits; A is now $FF if number was negative
;         sta     FPA+3                   ; Sign extend the 16-bit integer to 32-bit significand
;         sta     FPA+4
;         rts

; ; Truncate FPA to an integer and return it in the integer pointed to by AX.
; ; FPA must be in the range -32,768 to 32,767. FPA values aren't necessarily
; ; normalized so we could encounter 10 as 10E+0, 1E+1, or 100E-1. First we
; ; adjust the exponent to 0 by dividing or multiplying by 10. It's okay if, when dividing by 10,
; ; we lose digits off the right since this is a truncation function. After adjusting we check
; ; to see if the value is in range. 
; ; Returns error code in A.

; _truncate_fp_to_int:
; truncate_fp_to_int:
;         sta     ptr1                    ; Integer address into ptr1
;         stx     ptr1+1

; ; Make the exponent 0, which will leave the integer value int the two least-significant bytes
; ; of the significand.

; truncate_fp_to_int_ptr1:                ; Entry point if ptr1 already set
;         ldx     FPA                     ; Go get the exponent byte
;         beq     @to_int                 ; E was 0, go directly to getting int
;         bmi     @negative_e             ; E was negative

; ; E is positive.
; ; Adjust exponent down by multiplying significand by 10.

; @dec_e:
;         jsr     significand_mul_10
;         bcs     @err_out_of_range
;         dex
;         bne     @dec_e
;         jmp     @to_int

; ; Adjust exponent up by dividing by 10.
; ; If significand is negative then negate it first.

; @negative_e:
;         lda     FPA+4                   ; Check MSB of significand for sign
;         pha                             ; Remember what it was so we can restore later
;         bpl     @inc_e                  ; It was positive
;         jsr     fneg
; @inc_e:
;         jsr     significand_div_10
;         inx
;         bne     @inc_e
;         pla                             ; Recall the original MSB
;         bpl     @to_int                 ; It was positive before, no change
;         jsr     fneg

; @to_int:
;         lda     FPA+2                   ; MSB of 16-bit int value
;         asl     A                       ; Sign bit into carry
;         lda     #$FF
;         adc     #0                      ; A is 0 if sign bit was negative, $FF if positive
;         eor     #$FF                    ; Invert bits
;         cmp     FPA+3                   ; 2 most significant bytes of significand must be this value
;         bne     @err_out_of_range
;         cmp     FPA+4  
;         bne     @err_out_of_range
;         lda     FPA+1                   ; Low byte
;         ldx     FPA+2                   ; High byte
; @positive:
;         ldy     #0                      ; Index
;         sta     (ptr1),y                ; Store low byte
;         iny
;         txa
;         sta     (ptr1),y                ; Store high byte
;         jmp     return0                 ; Success

; @err_out_of_range:
;         lda     #ERR_OVERFLOW
;         ldx     #0
;         rts

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
        ldy     #Float::s
        clc
        lda     FPA+Float::s
        adc     (fp_ptr),y              ; Add the significands
        sta     FPA+Float::s
        iny
        lda     FPA+Float::s+1
        adc     (fp_ptr),y       
        sta     FPA+Float::s+1
        iny
        lda     FPA+Float::s+2
        adc     (fp_ptr),y        
        sta     FPA+Float::s+2
        iny
        lda     FPA+Float::s+3
        adc     (fp_ptr),y        
        sta     FPA+Float::s+3

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
.assert Float::e = 0, error
.assert Float::s = 1, error

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
        sta     FPA+Float::s+4          
        sta     FPA+Float::s+5           
        sta     FPA+Float::s+6
        sta     FPA+Float::s+7
        ldx     #32                     ; 32 multiplication cycles
@next_bit:
        lsr     FPB+Float::s+3          ; Shift the multiplicand right
        ror     FPB+Float::s+2
        ror     FPB+Float::s+1
        ror     FPB+Float::s
        bcc     @skip                   ; Bit 0 of multiplicand was zero; don't add
        ldy     #Float::s
        clc
        lda     FPA+Float::s+4          ; Add value to high 32 bits of FPA
        adc     (fp_ptr),y
        sta     FPA+Float::s+4
        iny
        lda     FPA+Float::s+5
        adc     (fp_ptr),y
        sta     FPA+Float::s+5
        iny
        lda     FPA+Float::s+6
        adc     (fp_ptr),y
        sta     FPA+Float::s+6
        iny
        lda     FPA+Float::s+7
        adc     (fp_ptr),y
        sta     FPA+Float::s+7
@skip:
        ror     FPA+Float::s+7          ; Shift carry and 64-bit FPA significand one place to right
        ror     FPA+Float::s+6
        ror     FPA+Float::s+5
        ror     FPA+Float::s+4
        ror     FPA+Float::s+3
        ror     FPA+Float::s+2
        ror     FPA+Float::s+1
        ror     FPA+Float::s
        dex                             ; Decrement bit counter
        bne     @next_bit               ; Keep going
        rts

; Divides the 64-bit significand by 10 until it fits into 32 bits.

shrink_significand:
        lda     FPA+Float::s+4
        ora     FPA+Float::s+5
        ora     FPA+Float::s+6
        ora     FPA+Float::s+7
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
        lda     FPA+Float::s+3          ; Get high byte of dividend
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
        asl     FPA+Float::s
        rol     FPA+Float::s+1
        rol     FPA+Float::s+2
        rol     FPA+Float::s+3
        rol     FPA+Float::s+4
        rol     FPA+Float::s+5
        rol     FPA+Float::s+6
        rol     FPA+Float::s+7
        lda     FPA+Float::s+7          ; Compare FPA extended siginficand with FPB (divisor)
        cmp     FPB+Float::s+3
        bcc     @less_than_divisor
        lda     FPA+Float::s+6
        cmp     FPB+Float::s+2
        bcc     @less_than_divisor
        lda     FPA+Float::s+5
        cmp     FPB+Float::s+1
        bcc     @less_than_divisor
        lda     FPA+Float::s+4
        cmp     FPB+Float::s
        bcc     @less_than_divisor
        sec                             ; Subtract dividend in FPB from FPA extended significand
        lda     FPA+Float::s+7
        sbc     FPB+Float::s+3
        sta     FPA+Float::s+7
        lda     FPA+Float::s+6
        sbc     FPB+Float::s+2
        sta     FPA+Float::s+6
        lda     FPA+Float::s+5
        sbc     FPB+Float::s+1
        sta     FPA+Float::s+5
        lda     FPA+Float::s+4
        sbc     FPB+Float::s
        sta     FPA+Float::s+4
        inc     FPA+Float::s            ; Increment quotient
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
