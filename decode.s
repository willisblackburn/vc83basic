.include "macros.inc"
.include "basic.inc"

; Functions to decode values from the token stream.
; Sometimes these functions will be called when one value has already been read and is in the A register;
; this will be noted.
; We don't have to worry about errors since we're decoding what we previously encoded.
; For all functions, lp is the read position in line_ptr.

; Decodes the an expression and invokes handlers as it encounters expression elements.
;   1xxx xxxx -> 0 (variable)
;   
;   0000 0000 -> x (will never be dispatched)
;   0000 0001 -> 1 (integer)
;   0000 0002 -> 2 (subexpression)
; vector_table_ptr = the table of vectors for dispatching; must be set up in advance!

.assert TOKEN_NO_VALUE = 0, error
.assert TOKEN_NUM = 1, error
.assert TOKEN_LPAREN = 2, error
.assert TOKEN_OP = $10, error
.assert TOKEN_VAR = $80, error

decode_expression:
        jsr     decode_byte
        bmi     @variable               ; Handle variable
        tax                             ; Move to X to use dex-beq logic (Z = TOKEN_NO_VALUE)
        dex                             ; Z = TOKEN_NUM
        beq     @integer                ; Handle integer
        dex                             ; Z = TOKEN_LPAREN
        beq     @subexpression

@error:
        sec                             ; Indicate error
        rts

@variable:
        and     #<(TOKEN_VAR - 1)       ; Mask out just the operator
        sta     B                       ; Transfer variable value into B
        ldy     #XH_VAR                 ; Choose handler
        jmp     @dispatch               ; Dispatch    

@integer:
        jsr     decode_number           ; Decode the integer
        stax    BC                      ; Park it in BC
        ldy     #XH_INT                 ; Choose handler                    
        jmp     @dispatch               ; Dispatch    

@subexpression:
        ldy     #XH_SUBX                ; Choose handler
        jmp     @dispatch

; At dispatch, Y should be set to the handler index.
; There may be a value in either X or BC that the handler can access.

@dispatch:
        jsr     invoke_indexed_vector_vt    ; Invoke the vector using the existng vector_table_ptr
        ldy     lp                      ; Before looking for an operator, check if we're at the end of the line
        cpy     next_line_offset        ; If next_line_offset > lp then we had to borrow and carry is clear
        beq     @done
        lda     (line_ptr),y            ; Peek at the next byte
        sbc     #(TOKEN_OP - 1)         ; Carry is clear so SBC will subtract one more than we need
        bcc     @check_rparen           ; If we had to borrow to do that subtract then no operator
        cmp     #TOKEN_OP               ; TOKEN_OP is conveniently the number of available operators + 1
        bcs     @check_rparen           ; If were able to subtract TOKEN_OP without borrowing (carry = 1) then no op
        sta     B                       ; Transfer variable value into B
        inc     lp                      ; Move line position past operator
        ldy     #XH_OP                  ; Operator handler
        jsr     invoke_indexed_vector_vt    ; Invoke the vector using the existng vector_table_ptr
        jmp     decode_expression    ; Get the following expression

; The next token was not an operator.
; Check if it's a right paren, in which case we will just discard it.
; The value in A has been decreased by TOKEN_OP so we have to take that into account.

@check_rparen:
        cmp     #<(TOKEN_RPAREN - TOKEN_OP)
        bne     @done
        inc     lp                      ; Skip the right paren
        clc
        rts

@done:
        clc                             ; Indicate success
        rts

; Decodes a number and returns it in AX.

decode_number:
        inc     lp                      ; Increment read position to high byte 
        ldy     lp                      ; Load position of high byte into Y
        inc     lp                      ; Increment read one position again
        lda     (line_ptr),y            ; Load the high byte of the number
        tax                             ; Move into X
        dey                             ; Decrement Y
        lda     (line_ptr),y            ; Get the low byte of the number into A
        rts     

; Decodes a single byte and returns it in A.
; The last instruction loads A, so this function will return with the Z and N flags set accordingly.

decode_byte:
        ldy     lp                      ; Read lp into Y and increment
        inc     lp  
        lda     (line_ptr),y            ; Load and return the byte
        rts
