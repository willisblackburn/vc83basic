; SPDX-FileCopyrightText: 2026 Willis Blackburn and Daniel Serpell
;
; SPDX-License-Identifier: MIT

.code
 
; OPEN [#channel] {name} [,{mode}]
exec_open:
        jsr     evaluate_expression     ; Evaluates filename -> S0
        jsr     push_pending            ; Push filename onto stack
        lda     #4                      ; Default mode = 4 (Read)
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
        sta     open_mode
        jsr     copy_s0_to_buffer_eol
        jsr     get_iocb_index          ; Sets IOCB index in X (0..$70) based on channel
        lda     #<buffer
        sta     ICBAL,x
        lda     #>buffer
        sta     ICBAH,x
        lda     open_mode
        sta     ICAX1,x
        lda     #0
        sta     ICAX2,x
        lda     #3                      ; OPEN
        sta     ICCOM,x
        jsr     CIOV
        cpy     #128
        bcs     @err
        rts

@open_type_mismatch:
        jmp     raise_type_mismatch

@err:
        raise   ERR_IO_ERROR

; CLOSE [#channel]
exec_close:
        jsr     get_iocb_index          ; Sets IOCB index in X based on channel
        lda     #12                     ; CLOSE
        sta     ICCOM,x
        jsr     CIOV
        rts

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
        jsr     get_iocb_index          ; Sets IOCB index in X based on channel
        lda     B
        sta     ICCOM,x
        lda     BC
        sta     ICAX1,x
        lda     DE
        sta     ICAX2,x
        jsr     CIOV
        cpy     #128
        bcs     @xio_err
        rts

@xio_err:
        raise   ERR_IO_ERROR

@xio_type_mismatch:
        jmp     raise_type_mismatch

exec_dos:
        jmp     (old_dosvec)

