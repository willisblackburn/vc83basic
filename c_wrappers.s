; Wrappers around assembly language functions to make them callable from C.
; The assembly language functions don't use the C stack, so the wrapper functions
; pop arguments from the C stack and put them in the right places before calling
; the assembly function.
; C prototypes are in test.h.

; cc65 runtime
.include "zeropage.inc"
.import popptr1, incsp2

.import memcpy_lower, memcpy_higher

.export _memcpy_lower, _memcpy_higher

; Same as popptr1 but for ptr2.
popptr2:
        ldy     #1
        lda     (sp),y
        sta     ptr2+1
        dey           
        lda     (sp),y
        sta     ptr2
        jmp     incsp2

_memcpy_lower:
        sta     sreg
        stx     sreg+1
        jsr     popptr1
        jsr     popptr2
        jmp     memcpy_lower

_memcpy_higher:
        sta     sreg
        stx     sreg+1
        jsr     popptr1
        jsr     popptr2
        jmp     memcpy_higher

