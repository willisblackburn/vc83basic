; SPDX-FileCopyrightText: 2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

.segment "BSS"
dir_record:     .res 15
dir_name        = dir_record
dir_size        = dir_record + 11

.segment "CODE"

; DIR statement:
; PROLOG_POP_STRING has already evaluated the path argument into S0, length in (BC) and A.
exec_dir:
        ; Check if Channel 7 is open by inspecting IOCB 7 ($02E0)
        lda     $02E0                   ; IOCB 7 device byte
        bpl     :+
        jmp     raise_io_error          ; Already open: fail without closing channel 7
:
        ; Set up arguments for API_OPEN
        ldy     #0
        lda     (BC), y                 ; String length
        sta     arg4
        lda     S0
        sta     arg2
        lda     S0+1
        sta     arg3
        lda     #4                      ; OPEN_DIRECTORY
        sta     arg1
        lda     #7                      ; Channel 7
        jsr     API_OPEN
        bcc     @dir_read_loop

        ; Open failed: fail immediately without closing channel 7
        jmp     raise_io_error

@dir_read_loop:
        lda     #<dir_record
        sta     arg1
        lda     #>dir_record
        sta     arg2
        lda     #15                     ; DIR_RECORD_SIZE
        sta     arg3
        lda     #0
        sta     arg4
        lda     #7
        jsr     API_READ
        bcc     @print_entry

        ; Read terminated: check if EOF or error
        cmp     #ERR_EOF
        beq     @close_ok

        ; Read error: close channel and raise IO error
        pha
        lda     #7
        jsr     API_CLOSE
        pla
        jmp     raise_io_error

@close_ok:
        lda     #7
        jsr     API_CLOSE
        rts

@print_entry:
        ; Print filename and pad to column 14
        ldx     #0
        ldy     #0
@print_name:
        lda     dir_name, y
        cmp     #' '
        beq     @name_done
        jsr     putch
        inx
        iny
        cpy     #8
        bne     @print_name

@name_done:
        ; Check if extension is non-spaces
        lda     dir_name + 8
        cmp     #' '
        bne     @print_ext_dot
        lda     dir_name + 9
        cmp     #' '
        bne     @print_ext_dot
        lda     dir_name + 10
        cmp     #' '
        beq     @pad_spaces

@print_ext_dot:
        lda     #'.'
        jsr     putch
        inx
        ldy     #8
@print_ext:
        lda     dir_name, y
        cmp     #' '
        beq     @pad_spaces
        jsr     putch
        inx
        iny
        cpy     #11
        bne     @print_ext

@pad_spaces:
        lda     #' '
        jsr     putch
        inx
        cpx     #14
        bcc     @pad_spaces

        ; Convert 32-bit size in dir_size to float and print
        lda     dir_size
        sta     FP0t
        lda     dir_size + 1
        sta     FP0t + 1
        lda     dir_size + 2
        sta     FP0t + 2
        lda     dir_size + 3
        sta     FP0t + 3
        lda     #0
        sta     FP0s                    ; Positive sign
        jsr     int32_to_fp             ; Convert 32-bit int in FP0t to float in FP0
        jsr     print_number
        jsr     newline

        jmp     @dir_read_loop

; STATUS [#channel,] variable
exec_status:
        jsr     get_variable
        lda     var_name_type
        bne     @status_type_mismatch
        lda     channel
        and     #$07
        jsr     API_STATUS
        bcs     @status_err
        ldx     #0
        jsr     int_to_fp
        jmp     assign_variable

@status_err:
        jmp     raise_io_error

@status_type_mismatch:
        jmp     raise_type_mismatch
