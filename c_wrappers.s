; Wrappers around assembly language functions to make them callable from C.
; The assembly language functions don't use the C stack, so the wrapper functions
; pop arguments from the C stack and put them in the right places before calling
; the assembly function.
; C prototypes are in test.h.

; cc65 runtime
.include "zeropage.inc"
.import popax, popptr1, incsp2, return0, return1

.include "basic.inc"

; Aliases for globals

_buffer = buffer
.export _buffer
_buffer_length = buffer_length
.export _buffer_length

_line_ptr = line_ptr
.export _line_ptr
_program_start = program_start
.export _program_start
_program_end = program_end
.export _program_end

; Function wrappers

; Same as popptr1 but for ptr2.
popptr2:
        ldy     #1
        lda     (sp),y
        sta     ptr2+1
        dey           
        lda     (sp),y
        sta     ptr2
        jmp     incsp2

; Returns 0 or 1 depending on the carry state.
return_carry:
        bcs     @error
        jmp     return0
@error:
        jmp     return1        

_initialize_arch:
.export _initialize_arch
        jmp     initialize_arch

_initialize_program:
.export _initialize_program
        jsr     initialize_program
        rts

_reset_line_ptr:
.export _reset_line_ptr
        jmp     reset_line_ptr

_find_line:
.export _find_line
        jsr     find_line
        jmp     return_carry

_advance_line_ptr:
.export _advance_line_ptr
        jmp     advance_line_ptr

_copy_bytes:
.export _copy_bytes
        sta     sreg
        stx     sreg+1
        jsr     popptr1
        jsr     popptr2
        jmp     copy_bytes

_copy_bytes_back:
.export _copy_bytes_back
        sta     sreg
        stx     sreg+1
        jsr     popptr1
        jsr     popptr2
        jmp     copy_bytes_back
