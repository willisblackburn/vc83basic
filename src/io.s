; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

; I/O statements and functions

.ifdef enable_io_channels
; OPEN [#channel] {name} [,{mode}]

exec_open:
        jsr     evaluate_expression     ; Evaluates filename -> S0
        jsr     push_pending            ; Push filename onto stack
        lda     #0                      ; Default mode = 0 (Read)
        pha
        jsr     peek_byte
        beq     @no_mode
        inc     line_pos
        jsr     evaluate_expression     ; Evaluates mode -> FP0
        bne     @open_type_mismatch
        jsr     truncate_fp_to_int      ; Mode in AX
        tsx
        sta     $101,x                  ; Replace default mode on stack
@no_mode:
        jsr     pop_string_s0           ; Pop filename into S0 (checks string type)
        pla                             ; Mode in A
        jsr     open
        bcs     raise_io_error
        rts

@open_type_mismatch:
        jmp     raise_type_mismatch

; CLOSE [#channel]

exec_close:
        jsr     close
        bcs     raise_io_error
        rts
.endif

; GET [#channel] {numeric_variable}

exec_get:
        jsr     get_variable
        lda     var_name_type
        bne     @type_mismatch
        jsr     getch
        ldx     #0                      ; High byte 0
        bcc     @got_byte               ; If not EOF then byte is in A
        lda     #$FF                    ; -1 in AX on EOF ($FFFF)
        dex
@got_byte:
        jsr     int_to_fp
        jmp     assign_variable

@type_mismatch:
        jmp     raise_type_mismatch

; PUT [#channel] {expression}
; PROLOG_POP_INT has already evaluated the expression and popped the byte into A!

exec_put:
        jsr     putch
        bcs     raise_io_error
        rts

raise_io_error:
        raise   ERR_IO_ERROR

.ifdef enable_io_channels
; XIO [#channel] {command}[,{arg1}[,{arg2}]]

exec_xio:
        jsr     evaluate_expression     ; Command -> FP0
        bne     @xio_type_mismatch
        jsr     truncate_fp_to_int
        sta     B                       ; Command in B
        lda     #0
        sta     BC                      ; Default arg1 = 0
        sta     BC+1
        sta     DE                      ; Default arg2 = 0
        sta     DE+1
        jsr     peek_byte
        beq     @do_xio
        inc     line_pos
        jsr     evaluate_expression     ; Arg1 -> FP0
        bne     @xio_type_mismatch
        jsr     truncate_fp_to_int
        stax    BC
        jsr     peek_byte
        beq     @do_xio
        inc     line_pos
        jsr     evaluate_expression     ; Arg2 -> FP0
        bne     @xio_type_mismatch
        jsr     truncate_fp_to_int
        stax    DE

@do_xio:
        lda     B                       ; Command in A
        jsr     xio
        bcs     raise_io_error
        rts

@xio_type_mismatch:
        jmp     raise_type_mismatch
.endif

; SAVE {name}
; PROLOG_POP_STRING has already evaluated the filename and loaded S0!

exec_save:
        jsr     save
        bcs     raise_io_error
        rts

; LOAD {name}
; PROLOG_POP_STRING has already evaluated the filename and loaded S0!

exec_load:
        ldy     #Line::next_line_offset
        lda     (program_ptr),y
        beq     @empty
        jmp     raise_exists            ; Program exists: user must do NEW first!
@empty:
        jsr     load
        bcs     raise_io_error
        rts

; INKEY$() function
; EPILOG_PUSH_STRING pushes string returned in S0 / string_ptr

fun_inkey_s:
        jsr     inkey
        bcs     @no_key
        pha                             ; Save character
        lda     #1
        jsr     string_alloc_for_copy
        pla
        ldy     #0
        sta     (dst_ptr),y
        rts

@no_key:
        lda     #0
        jmp     string_alloc
