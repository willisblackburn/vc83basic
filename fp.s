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
; Exponent range is 10^-132 to 10^123
; Significand range is -2,147,483,648 to 2,147,483,647

MAXDIGITS = 10

.zeropage

; We make a lot of assumptions about the size of Float in ths module.
.assert .sizeof(Float) = 5, error
.assert .sizeof(Float::exponent) = 1, error
.assert .sizeof(Float::significand) = 4, error

; FP accumulator + extended significand
FPA: .res 9
; Secondary FP register
FPB: .res 5

; fp_ptr holds a pointer to the other argument in two-float operations
fp_ptr: .res 2

.code

; Loads FP value into FPA.
; AX is the address of the FP value.
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
; AX is the address of the FP value.
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
; No return value.
; X SAFE, Y SAFE, BC SAFE, DE SAFE

clear_fpa:
        lda     #0
        sta     FPA+Float::exponent
        sta     FPA+Float::significand
        sta     FPA+Float::significand+1
        sta     FPA+Float::significand+2
        sta     FPA+Float::significand+3
        rts

; ; Loads FP value into FPX.
; ; AX is the address of the FP value.
; ; Uses Y but does not use X after the _ptr1 entry point.

; _load_fpx:
; load_fpx:
;         sta     ptr1            ; FP value address into ptr1
;         stx     ptr1+1
; load_fpx_ptr1:                  ; Entry point if ptr1 is already set
;         ldy     #4              ; Counts down from 4 to 0 for 5 bytes total
; @next_byte:
;         lda     (ptr1),y
;         sta     FPX,y
;         dey                     ; Decrement byte counter
;         bpl     @next_byte      ; Continue if it hasn't rolled over
;         rts

; ; Stores FP value from FPA into memory.
; ; AX is the address of the FP value.
; ; Uses Y but does not use X after the _ptr1 entry point.

; _store_fpx:
; store_fpx:
;         sta     ptr1            ; FP value address into ptr1
;         stx     ptr1+1
; store_fpx_ptr1:                 ; Entry point if ptr1 is already set
;         ldy     #4
; @next_byte:
;         lda     FPX,y
;         sta     (ptr1),y
;         dey                     ; Decrement byte counter
;         bpl     @next_byte      ; Continue if it hasn't rolled over
;         rts

; ; Stores 0 into FPX.
; ; No return value.
; ; Does not use X or Y.

; _clear_fpx:
; clear_fpx:
;         stz     FPX            
;         stz     FPX+1
;         stz     FPX+2
;         stz     FPX+3
;         stz     FPX+4
;         rts

; Copies FPA to FPB
; No return value.
; X SAFE, Y SAFE, BC SAFE, DE SAFE

copy_fpa_to_fpb:
        lda     FPA+Float::exponent
        sta     FPB+Float::exponent
copy_fpa_significand_to_fpb:
        lda     FPA+Float::significand
        sta     FPB+Float::significand
        lda     FPA+Float::significand+1
        sta     FPB+Float::significand+1
        lda     FPA+Float::significand+2
        sta     FPB+Float::significand+2
        lda     FPA+Float::significand+3
        sta     FPB+Float::significand+3
        rts

; ; Copies FPX to FPA
; ; No return value.
; ; Does not use X or Y.

; _copy_fpx_to_fpa:
; copy_fpx_to_fpa:
;         lda     FPX
;         sta     FPA
; copy_fpx_significand_to_fpa:
;         lda     FPX+1
;         sta     FPA+1
;         lda     FPX+2
;         sta     FPA+2
;         lda     FPX+3
;         sta     FPA+3
;         lda     FPX+4
;         sta     FPA+4
;         rts

; ; Swaps FPA and FPX.
; ; No return value.
; ; Clobbers both X and Y.

; _swap_fpa_fpx:
; swap_fpa_fpx:
;         ldx     #4              ; 4 goes from 5 -> 0
; @next_byte:
;         lda     FPA,x           ; Swap one byte of FPA and FPX
;         ldy     FPX,x
;         sta     FPX,x
;         sty     FPA,x
;         dex                     ; Decrement counter
;         bpl     @next_byte      ; Continue if it hasn't rolled over
;         rts

; ; Swaps FPA with another value.
; ; AX points to the other value.
; ; Clobbers both X and Y.

; _swap_fpa:
; swap_fpa:
;         sta     ptr1            ; FP value address into ptr1
;         stx     ptr1+1
; swap_fpa_ptr1:
;         ldy     #4              ; Y goes from 4 -> 0
; @next_byte:
;         ldx     FPA,y           ; Swap one byte
;         lda     (ptr1),y
;         sta     FPA,y           ; Uses $nnnn,y addressing but no way to avoid
;         txa
;         sta     (ptr1),y
;         dey
;         bpl     @next_byte      ; Continue if it hasn't rolled over
;         rts

; Checks if FPA is zero.
; FPA is zero if the significand is zero.
; On return, the Z flag will indicate whether FPA is zero. If FPA is zero, A will also be zero.
; X SAFE, Y SAFE, BC SAFE, DE SAFE

fpa_is_zero:
        lda     FPA+Float::significand
        ora     FPA+Float::significand+1
        ora     FPA+Float::significand+2
        ora     FPA+Float::significand+3
        rts

; Multiplies the FPA significand by 10. Copies the FPA value into FPX.
; On return the carry will be set if the multiplication caused an overflow.
; On overflow, the original value can be recovered from FPX.
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
        lda     FPA+Float::exponent
        lda     FPA+Float::significand
        lda     FPA+Float::significand+1
        lda     FPA+Float::significand+2
        lda     FPA+Float::significand+3
        rts

; Shifts the signifiand of FPA left, multiplying it by 2.

@shift_significand:
        asl     FPA+Float::significand
        rol     FPA+Float::significand+1
        rol     FPA+Float::significand+2
        rol     FPA+Float::significand+3
        rts

; Adds the significand of FPX to FPA.

@add_significands:
        clc
        lda     FPA+Float::significand
        adc     FPB+Float::significand
        sta     FPA+Float::significand
        lda     FPA+Float::significand+1
        adc     FPB+Float::significand+1
        sta     FPA+Float::significand+1
        lda     FPA+Float::significand+2
        adc     FPB+Float::significand+2
        sta     FPA+Float::significand+2
        lda     FPA+Float::significand+3
        adc     FPB+Float::significand+3
        sta     FPA+Float::significand+3
        rts

; Divides the FPA significand by 10.
; Returns the remainder in A.
; The second entry point preserves the existing value in A and is used when
; the addition of two significands causes the field to overflow.
; Uses X to keep track of the shift count.
; Y SAFE, BC SAFE, DE SAFE

significand_div_10:
        lda     #0                      ; Initialize remainder to 0
        ldx     #32                     ; 32 bits
@next_bit:
        asl     FPA+Float::significand  ; LSB of FPA+1 (least significant byte) is now 0
        rol     FPA+Float::significand+1
        rol     FPA+Float::significand+2
        rol     FPA+Float::significand+3
        rol     A                       ; Bits from significand move into A
        cmp     #10                     ; C ("don't borrow") set if A>=10
        bcc     @not_10                 ; It's <10
        inc     FPA+Float::significand  ; Increment quotient
        sbc     #10                     ; C will still be set here
@not_10:
        dex
        bne     @next_bit               ; More bits to shift
        rts

; ; Divides the extended FPA significand by 10.
; ; Identical to signficand_div_10 except the dividend is the 64-bit extended FPA register.

; significand_div_10_ext:
;         lda     #0              ; Initialize remainder to 0
;         ldy     #64             ; 32 bits
; @next_bit:
;         asl     FPA+1           
;         rol     FPA+2
;         rol     FPA+3
;         rol     FPA+4
;         rol     FPA+5
;         rol     FPA+6
;         rol     FPA+7
;         rol     FPA+8
;         rol     A               
;         cmp     #10             
;         bcc     @not_10         
;         inc     FPA+1           
;         sbc     #10             
; @not_10:
;         dey
;         bne     @next_bit       
;         rts

; ; Saves the MSB of the FPA signifcand in the ZP location pointed to by X
; ; and negates the significand if it's negative. The saved MSB will be used
; ; later to determine if the value needs to be negated later.

; negate_negative:
;         lda     FPA+4           ; MSB of significand
;         sta     0,x
;         bmi     fneg
;         rts

; ; Loads MSB that was saved earlier in the ZP location pointed to by X and
; ; negates the significand if it was previously negative.

; restore_negative_signifiand:
;         lda     0,x             ; Retrieve MSB of significand
;         bmi     fneg
;         rts

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
        lda     FPA+Float::significand+3    ; MSB of significand
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
        lda     FPA+Float::exponent     ; Get exponent
        bmi     @negative_exponent
        tya                             ; Number of generated digits into A
        clc  
        adc     FPA+Float::exponent     ; A = Y + E digits
        cmp     #MAXDIGITS+1            ; Add 1 to make carry set indicate >MAXDIGITS instead of >=MAXDIGITS
        bcs     @scientific             ; It's over so print in scientific notation

; Simple output case for <=MAXDIGITS digits and exponent >= 0.

        jsr     output_y_digits
        ldy     FPA+Float::exponent     ; Positive E is number of trailing zeros (possibly zero)
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
        adc     FPA+Float::exponent     ; Y + E
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
        adc     FPA+Float::exponent     ; A = E + X-1
        sta     FPA+Float::exponent     ; Store back in FPA
        jsr     output_y_digits
        jsr     remove_trailing_zeros
        jmp     @generate_e

; Output exponent in FPA.
; Same logic as above, but only FPA is involved.

@generate_e:
        lda     #'E'
        sta     buffer,x
        inx
        lda     FPA+Float::exponent     ; Sets N if exponent < 0
        bpl     @e_positive
        eor     #$FF            
        sta     FPA+Float::exponent     ; Exponent is now positive
        inc     FPA+Float::exponent     ; Except not really, still have to do the +1
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
        asl     FPA+Float::exponent
        rol     A
        cmp     #10
        bcc     @e_not_10
        inc     FPA+Float::exponent
        sbc     #10                     ; Carry must be set here
@e_not_10:
        dex
        bne     @e_next_bit
        clc
        adc     #'0'
        pha
        iny                             ; Increment generated digits
        lda     FPA+Float::exponent
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
        adc     FPA+Float::significand  ; Add digit to LSB
        sta     FPA+Float::significand
        bcc     @next_character         ; If no carry then next character
        inc     FPA+Float::significand+1    ; Otherwise increment next byte
        bne     @next_character         ; etc,
        inc     FPA+Float::significand+2
        bne     @next_character
        inc     FPA+Float::significand+3
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
        lda     FPA+Float::exponent
        sbc     D
        bvs     @err_overflow           ; Adjusting E might cause signed overflow
        sta     FPA+Float::exponent     ; Store exponent
        plp                             ; Go get the '-' comparison from earlier
        bne     @positive               ; There was no '-' at the start of the string
        jsr     fneg
        bpl     @err_overflow_2         ; Overflow if we were expecting negative but number is positive
        clc
        rts

@positive:
        lda     FPA+Float::significand+3
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
        lda     FPA+Float::exponent     ; Get exponent
        asl     A                       ; Exponent *2
        bcs     @err_overflow_in_e
        asl     A                       ; *4
        bcs     @err_overflow_in_e
        adc     FPA+Float::exponent     ; *5, carry guaranteed to be clear
        bcs     @err_overflow_in_e
        asl     A                       ; *10
        bcs     @err_overflow_in_e
        adc     D                       ; Add in the new digit
        bcs     @err_overflow_in_e
        bmi     @err_overflow_in_e      ; If it goes negative then fail
        sta     FPA+Float::exponent
        jmp     @next_character_e

@finish_e:
        plp                             ; Get the '-' comparison from before
        bne     @finish                 ; If it wasn't negative then all done
        lda     FPA+Float::exponent     ; Negate exponent
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

; ; Adds a value to FPA, returning result in FPA.
; ; The strategy is to get the number with the larger exponent into FPA.

; _fadd:
; fadd:
;         sta     ptr1            ; Address of other value into ptr1
;         stx     ptr1+1
; fadd_ptr1:
;         lda     (ptr1)          ; ptr1 exponent
;         sec
;         sbc     FPA             ; If N eor V then ptr1 exponent < FPA exponent
;         beq     @equal_exponents ; Exponents are equal, just go ahead to addition
;         bvc     @v_clear
;         eor     #$80            ; V is 1 and A7 is N so this does N eor V
; @v_clear:
;         bmi     @fpa_greater    ; If N eor V then ptr1 exponent < FPA exponent so don't swap
;         jsr     swap_fpa_ptr1   ; Swap FPA with the value (clobbers X and Y)
; @fpa_greater:
;         lda     FPA             ; FPA exponent is greater
;         sec                     ; so when we subtract ptr1 exponent,
;         sbc     (ptr1)          ; we'll get the unsigned difference
;         sta     tmp3            ; Park exponent differerence in tmp3

; ; TODO: detect if we've reached limit of exponent range.
; ; TODO: detect if exponent difference is too great and just return FPA in this case.
; ; TODO: can probably eliminate one of these swaps, or just have a function to negate ptr1.

; ; Negate negative numbers before adjusting.

;         ldx     #tmp1           ; Store sign of FPA in tmp1
;         jsr     negate_negative
;         jsr     swap_fpa_ptr1   ; Swap values
;         ldx     #tmp2           ; Sign of ptr1 value in tmp2
;         jsr     negate_negative
;         jsr     swap_fpa_ptr1   ; Restore FPA and ptr1
;         ldx     tmp3            ; Use X to track the exponent difference

; ; Try to make the greater exponent of FPA equal to the exponent of FPX by multiplying it by 10.
; ; Stop either when the exponents are equal or when the multiplication overflows.

; @grow:
;         jsr     significand_mul_10 ; Trial multiplication by 10
;         bcs     @fpa_overflow   ; Can't do this anymore, FPA overflowed
;         bmi     @fpa_overflow   ; Or it went negative
;         dec     FPA             ; It worked so decrement exponent and X and try again                     
;         dex                      
;         bne     @grow
;         jmp     @restore_significands

; ; We can't equalize exponents by multiplying FPA, so now we have to divide the value, which
; ; will result in some loss of precision. We have to swap the arguments temporarily here because
; ; we can only divide FPA.

; @fpa_overflow:
;         jsr     copy_fpx_significand_to_fpa ; Recover saved significand from FPX
;         jsr     swap_fpa_ptr1
; @shrink:
;         jsr     significand_div_10 ; Divide FPA by 10
;         inc     FPA             ; Increment exponent
;         dex                     ; Close the exponent gap
;         bne     @shrink         ; Still more to do        
;         jsr     swap_fpa_ptr1   ; Swap back before continuing

; ; When both exponents are equal we can just add the significand of the value to that of FPA. 

; @restore_significands:
;         ldx     #tmp1
;         jsr     restore_negative_signifiand
;         jsr     swap_fpa_ptr1   ; Swap values
;         ldx     #tmp2
;         jsr     restore_negative_signifiand

; @equal_exponents:
;         ldy     #1
;         clc
;         lda     FPA+1
;         adc     (ptr1),y        ; Add the significands
;         sta     FPA+1
;         iny
;         lda     FPA+2
;         adc     (ptr1),y       
;         sta     FPA+2
;         iny
;         lda     FPA+3
;         adc     (ptr1),y        
;         sta     FPA+3
;         iny
;         lda     FPA+4
;         adc     (ptr1),y        
;         sta     FPA+4

; ; If the addition has caused signed overflow, divide the significand by 10
; ; and increase the exponent.

; ; TODO: this doesn't work; I need to negate before dividing by 10

;         bvs     @overflow
;         jmp     return0

; @overflow:
;         lda     #1
;         jsr     significand_div_10_ext
;         inc     FPA
;         jmp     return0

; ; Subtracts a value from FPA, returning result in FPA.
; ; Simply negates the value and then delegates to fadd.

; _fsub:
; fsub:
;         sta     ptr1            ; Address of other value into ptr1
;         stx     ptr1+1
; fsub_ptr1:
;         jsr     swap_fpa_ptr1   ; Swap the values
;         jsr     fneg            ; because we have a negation function for FPA
;         jmp     fadd_ptr1       ; Continue as fadd

; ; Muliplies FPA by the a value, returning the result in FPA.
; ; Scales FPA so product fits into signficand.

; _fmul:
; fmul:
;         sta     ptr1            ; Address of other value into ptr1
;         stx     ptr1+1
; fmul_ptr1:

; ; TODO: just have negate_negative return MSB in A.

;         ldx     #tmp1           ; Store sign of FPA in tmp1
;         jsr     negate_negative
;         jsr     swap_fpa_ptr1   ; Swap values
;         ldx     #tmp2           ; Sign of ptr1 value in tmp2
;         jsr     negate_negative
;         jsr     swap_fpa_ptr1   ; Restore FPA and ptr1
;         jsr     copy_fpa_to_fpx ; FPA -> FPX so we can use FPA for product
;         lda     (ptr1)          ; Load ptr1 exponent
;         clc
;         adc     FPA             ; Add FPA
;         bvs     @err_overflow   ; If overflow then fail
;         sta     FPA             ; Store result exponent back in FPA
;         stz     FPA+5           ; Zero out the high 32 bits of the product
;         stz     FPA+6           
;         stz     FPA+7
;         stz     FPA+8
;         ldx     #32             ; 32 multiplication cycles
; @next_bit:
;         lsr     FPX+4           ; Shift the multiplicand right
;         ror     FPX+3
;         ror     FPX+2
;         ror     FPX+1
;         bcc     @skip           ; Bit 0 of multiplicand was zero; don't add
;         clc
;         ldy     #1              ; Y will index ptr1
;         lda     FPA+5           ; Add ptr1 to high 32 bits of FPA
;         adc     (ptr1),y
;         sta     FPA+5
;         iny
;         lda     FPA+6
;         adc     (ptr1),y
;         sta     FPA+6
;         iny
;         lda     FPA+7
;         adc     (ptr1),y
;         sta     FPA+7
;         iny
;         lda     FPA+8
;         adc     (ptr1),y
;         sta     FPA+8
; @skip:
;         ror     FPA+8           ; Shift carry and 64-bit FPA one place to right
;         ror     FPA+7
;         ror     FPA+6
;         ror     FPA+5
;         ror     FPA+4
;         ror     FPA+3
;         ror     FPA+2
;         ror     FPA+1
;         dex                     ; Decrement bit counter
;         bne     @next_bit       ; Keep going

; ; There is a 64-bit product in the extended FPA register.
; ; Divide the product by 10 until the top word is clear.

; @shrink:
;         lda     FPA+5
;         ora     FPA+6
;         ora     FPA+7
;         ora     FPA+8
;         beq     @done
;         jsr     significand_div_10_ext
;         inc     FPA             ; Increase exponent to compensate for division
;         jmp     @shrink

; @done:
;         lda     tmp1            ; Get original MSB of FPA
;         eor     tmp2            ; EOR with original MSB of ptr1
;         bpl     @positive       ; Both were positive, or both negative, so product is positive
;         jsr     fneg            ; Product is negative
; @positive:
;         jmp     return0

; @err_overflow:
;         lda     #ERR_OVERFLOW
;         ldx     #0
;         rts
