.include "macros.inc"
.include "basic.inc"

.zeropage

; Current position in the control stack
csp: .res 1

.bss

.assert .sizeof(Control) <= CONTROL_SIZE, error

; Stack for handling GOSUB, RETURN, and FOR
control_stack: .res CONTROL_STACK_DEPTH * CONTROL_SIZE

.code

exec_goto:
        jsr     decode_number           ; Go get the line number
        jsr     find_line               ; Find the program line
        rts                             ; Either next_line_ptr is set or carry (error) is set

; The actual size has to match the shift logic.
.assert CONTROL_SIZE = 16, error

exec_gosub:
        jsr     get_control_stack_index ; Set X to control stack index
        bcs     @done                   ; If csp was out of range
        lda     next_line_ptr           ; Store next_line_ptr on control stack
        sta     control_stack+Control::next_line_ptr,x
        lda     next_line_ptr+1
        sta     control_stack+Control::next_line_ptr+1,x
        jsr     decode_number           ; GOSUB line number
        jsr     find_line               ; Find the line
        bcs     @done
        inc     csp                     ; Success, so increment the control stack pointer
@done:
        rts

exec_return:
        sec                             ; Set carry so can return error if csp = 0
        lda     csp
        beq     @done
        dec     csp
        jsr     get_control_stack_index ; Set X to control stack index; clears carry
        lda     control_stack+Control::next_line_ptr,x
        sta     next_line_ptr           ; Restore next_line_ptr value
        lda     control_stack+Control::next_line_ptr+1,x
        sta     next_line_ptr+1
@done:
        rts

; Common function that sets the X register to the correct offset for the csp value.
; If csp is < CONTROL_SIZE, returns carry clear and X set to the offset, or returns carry set if csp is out of range.

get_control_stack_index:
        lda     csp                     
        cmp     #CONTROL_SIZE
        beq     @done                   ; Return with carry set
        asl     A                       ; Multiply stack postion by 16
        asl     A
        asl     A
        asl     A
        tax
@done:
        rts
