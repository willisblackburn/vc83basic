; cc65 runtime
.include "zeropage.inc"
.import incsp4

.import memcpy_lower, memcpy_higher

.export _memcpy_lower, _memcpy_higher

_memcpy_lower:
        sta     sreg
        stx     sreg+1
        ldy     #0
        lda     (sp),y
        sta     ptr1
        iny
        lda     (sp),y
        sta     ptr1+1
        iny
        lda     (sp),y
        sta     ptr2
        iny
        lda     (sp),y
        sta     ptr2+1
        jsr     memcpy_lower
        jmp     incsp4

_memcpy_higher:
        sta     sreg
        stx     sreg+1
        ldy     #0
        lda     (sp),y
        sta     ptr1
        iny
        lda     (sp),y
        sta     ptr1+1
        iny
        lda     (sp),y
        sta     ptr2
        iny
        lda     (sp),y
        sta     ptr2+1
        jsr     memcpy_higher
        jmp     incsp4
