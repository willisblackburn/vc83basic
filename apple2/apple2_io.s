

newline = CROUT

readline:
        mva     #$80, PROMPT
        jsr     GETLN
        ldx     #$FF                    ; Go looking for the "RETURN" character
@next:      
        inx     
        lda     buffer,x        
        and     #$7F                    ; Clear bit 7 if it's set
        sta     buffer,x                ; Store back
        cmp     #$0D        
        bne     @next       
        lda     #0      
        sta     buffer,x                ; Replace "RETURN" with 0
        txa                             ; Return buffer length in A
        rts

write:
        stax    BC
        sty     D
        ldy     #0
@next:
        cpy     D
        beq     @done
        lda     (BC),y
        jsr     putch
        iny
        jmp     @next

@done:
        rts

putch:
        ora     #$80
        jmp     COUT

.code
        