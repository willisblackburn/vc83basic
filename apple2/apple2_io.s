; cc65 runtime
.include "zeropage.inc"
.import push0, push1, pushax

.include "apple2.inc"
.include "../target.inc"

buffer := $200

.bss

buffer_length: .res 1

.code 

getchar = KEYIN
newline = CROUT

readline:
        jsr     GETLNNOPMPT
        ldx     #$FF            ; Go looking for the "RETURN" character
@next:
        inx
        lda     buffer,x
        and     #$7F            ; Clear high bit if it's set
        sta     buffer,x        ; Store back
        cmp     #$0D
        bne     @next
        stx     buffer_length
        rts

write_buffer:
        lda     #<buffer
        ldx     #>buffer
        ldy     buffer_length
write:
        sta     ptr1
        stx     ptr1+1
        sty     tmp1
        ldy     #0
@next:
        cpy     tmp1
        beq     @done
        lda     (ptr1),y
        jsr     putchar
        iny
        jmp     @next

@done:
        rts

putchar:
        ora     #$80
        jmp     COUT
        