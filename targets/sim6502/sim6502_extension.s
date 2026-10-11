; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

.code

; exit function provided by sim6502
.import exit

; OPEN [#channel] {name} [,{mode}]
exec_open:
        jsr     evaluate_expression     ; Evaluates filename -> S0
        jsr     push_pending            ; Push filename onto stack
        lda     #O_RDONLY               ; Default mode = O_RDONLY (Read)
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
        sta     open_flags
        lda     channel
        and     #$07
        tax
        lda     channel_fds,x           ; Check if already open
        cmp     #$FF
        bne     @raise_io_error         ; Already open -> fail

        jsr     copy_s0_to_buffer_nul
        ldax    #buffer
        jsr     pushax                  ; Push filename pointer
        lda     open_flags
        jsr     pusha0                  ; Push open flags
        lda     #$FF                    ; Mode 0777 permission ($01FF)
        ldx     #$01
        jsr     pushax
        ldy     #6                      ; 3 arguments (6 bytes)
        jsr     _open                   ; Call C open()
        cpx     #$80                    ; Negative return value?
        bcs     @raise_io_error
        tay                             ; Save fd in Y
        lda     channel
        and     #$07
        tax                             ; Channel index in X
        tya                             ; Restore fd in A
        sta     channel_fds,x           ; Save file descriptor
        rts

@open_type_mismatch:
        jmp     raise_type_mismatch

@raise_io_error:
        raise   ERR_IO_ERROR

; CLOSE [#channel]
exec_close:
        lda     channel
        and     #$07
        tax
        beq     @done                   ; Channel 0 (console) is never closed
        lda     channel_fds,x           ; Get fd
        cmp     #$FF
        beq     @done                   ; If already closed, leave it closed
        pha
        lda     #$FF                    ; Mark closed
        sta     channel_fds,x
        pla
        ldx     #0
        jsr     _close
@done:
        rts

; BYE: exits the interpreter

exec_bye:
        jmp     exit

version:
.include "version.inc"
version_length = * - version

fun_ver_s:
        lda     #version_length         ; Ignore argument
        jsr     string_alloc_for_copy
        ldax    #version
        jmp     copy_y_from
