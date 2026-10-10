; SPDX-FileCopyrightText: 2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

.segment "BSS"
dir_record:     .res 15
dir_name        = dir_record
dir_size        = dir_record + 11

current_color:  .res 1
last_x:         .res 2
last_y:         .res 2
target_x:       .res 2
target_y:       .res 2
delta_x:        .res 2
delta_y:        .res 2
major_delta:    .res 2
minor_delta:    .res 2
line_count:     .res 2
sx_whole:       .res 2
sy_whole:       .res 2
major_step_whole: .res 2
major_step_frac:  .res 1
diag_step_whole:  .res 2
tmp_b:          .res 1
tmp_g:          .res 1
tmp_r:          .res 1
tmp_n:          .res 1
tmp_p:          .res 1
tmp_l:          .res 1


.segment "CODE"

; DIR statement:
; PROLOG_POP_STRING has already evaluated the path argument into S0, length in (BC) and A.
exec_dir:
        ; Check if Channel 7 is open by inspecting IOCB 7 ($02E0)
        lda     $02E0                   ; IOCB 7 device byte
        bpl     @channel_available
        jmp     raise_io_error          ; Already open: fail without closing channel 7
@channel_available:
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
        clc
        rts

@print_entry:
        ; Print filename and pad to column 14
        lda     #0
        sta     D
        ldy     #0
@print_name:
        lda     dir_name, y
        cmp     #' '
        beq     @name_done
        tax
        tya
        pha
        txa
        jsr     putch
        pla
        tay
        inc     D
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
        inc     D
        ldy     #8
@print_ext:
        lda     dir_name, y
        cmp     #' '
        beq     @pad_spaces
        tax
        tya
        pha
        txa
        jsr     putch
        pla
        tay
        inc     D
        iny
        cpy     #11
        bne     @print_ext

@pad_spaces:
        lda     D
        cmp     #14
        bcs     @print_size
        lda     #' '
        jsr     putch
        inc     D
        jmp     @pad_spaces

@print_size:

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
        jsr     ensure_channel_0
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

; GRMODE mode
; Configures VCGA graphics layers.
; Mode argument:
;   Bits 4:0: format argument for VCGALAYER on Layer 3
;   Bit 7: if set, configure 4-line text window on Layer 2; if clear, disable Layer 2
;   Bits 6:5: must be 0 (frame is fixed to 640x400)
;   Layers 0 and 1 are disabled.
exec_grmode:
        cpx     #0
        bne     @err
        tax
        and     #$60
        bne     @err
        stx     E

        ; Disable layers 0 and 1
        lda     #0
        sta     arg1
        jsr     API_VCGALAYER
        lda     #1
        jsr     API_VCGALAYER

        ; Configure layer 3 (main layer: frame 0, full part, base 0)
        lda     #$04            ; frame 00, part 1 (full)
        sta     arg1
        lda     E
        and     #$1F
        sta     arg2
        lda     #0
        sta     arg3
        sta     arg4
        lda     #3
        jsr     API_VCGALAYER
        bcs     @err

        ; Configure or disable layer 2 (text window)
        lda     E
        bpl     @disable_layer2

        ; Bit 7 is set: 4-line text window on layer 2 at bottom
        lda     #$18            ; frame 00, part 6 (bottom 32)
        sta     arg1
        lda     #$10            ; text, 1 bpp, 1X
        sta     arg2
        lda     #0
        sta     arg3
        lda     #$FE            ; base = $FE00
        sta     arg4
        lda     #2
        jsr     API_VCGALAYER
        bcs     @err
        rts

@disable_layer2:
        lda     #0
        sta     arg1
        lda     #2
        jsr     API_VCGALAYER
        rts

@err:
        jmp     raise_out_of_range

; ===========================================================================
; COLOR n
; Sets current drawing color.
; ===========================================================================
exec_color:
        sta     current_color
        rts

; ===========================================================================
; PLOT x, y
; Sets the pixel at (x, y) to current drawing color and updates last point.
; ===========================================================================
exec_plot:
        sta     target_y
        stx     target_y+1
        jsr     pop_int_fp0
        sta     target_x
        stx     target_x+1

        lda     target_x
        sta     last_x
        lda     target_x+1
        sta     last_x+1
        lda     target_y
        sta     last_y
        lda     target_y+1
        sta     last_y+1

plot_current_pixel:
        lda     #MODE_4BPP
        sta     MODE

        ; Address = last_y * 80 + (last_x >> 1)
        lda     last_y
        sta     MUL_A
        lda     last_y+1
        sta     MUL_A+1

        lda     #80
        sta     MUL_B
        lda     #0
        sta     MUL_B+1

        lda     last_x+1
        lsr     A
        sta     MUL_C+1
        lda     last_x
        ror     A
        sta     MUL_C
        lda     #0
        sta     MUL_C+2

        sta     MUL_TO_DST

        lda     #$80
        sta     DST_ADDR+2

        lda     last_x
        and     #1
        asl     A
        asl     A
        sta     DST_FRAC

        bit     DST_DATA
        lda     current_color
        sta     DST_DATA
        rts

; ===========================================================================
; DRAWTO x, y
; Draws a line from (last_x, last_y) to (x, y) using hardware line mode.
; ===========================================================================
exec_drawto:
        sta     target_y
        stx     target_y+1
        jsr     pop_int_fp0
        sta     target_x
        stx     target_x+1

        ; Calculate delta_x and sx_whole
        sec
        lda     target_x
        sbc     last_x
        sta     delta_x
        lda     target_x+1
        sbc     last_x+1
        sta     delta_x+1
        bcs     @x_pos

        lda     #0
        sec
        sbc     delta_x
        sta     delta_x
        lda     #0
        sbc     delta_x+1
        sta     delta_x+1
        lda     #$FF
        sta     sx_whole
        sta     sx_whole+1
        jmp     @calc_dy

@x_pos:
        lda     #0
        sta     sx_whole
        sta     sx_whole+1

@calc_dy:
        ; Calculate delta_y and sy_whole
        sec
        lda     target_y
        sbc     last_y
        sta     delta_y
        lda     target_y+1
        sbc     last_y+1
        sta     delta_y+1
        bcs     @y_pos

        lda     #0
        sec
        sbc     delta_y
        sta     delta_y
        lda     #0
        sbc     delta_y+1
        sta     delta_y+1
        lda     #$B0
        sta     sy_whole
        lda     #$FF
        sta     sy_whole+1
        jmp     @calc_diag

@y_pos:
        lda     #80
        sta     sy_whole
        lda     #0
        sta     sy_whole+1

@calc_diag:
        ; diag_step_whole = sx_whole + sy_whole
        clc
        lda     sx_whole
        adc     sy_whole
        sta     diag_step_whole
        lda     sx_whole+1
        adc     sy_whole+1
        sta     diag_step_whole+1

        ; Compare delta_x and delta_y
        sec
        lda     delta_x
        sbc     delta_y
        lda     delta_x+1
        sbc     delta_y+1
        bcc     @mostly_vertical

        ; Case A: delta_x >= delta_y (mostly horizontal)
        lda     delta_x
        sta     major_delta
        lda     delta_x+1
        sta     major_delta+1
        lda     delta_y
        sta     minor_delta
        lda     delta_y+1
        sta     minor_delta+1

        lda     sx_whole
        sta     major_step_whole
        lda     sx_whole+1
        sta     major_step_whole+1
        lda     #$20
        sta     major_step_frac
        jmp     @setup_line

@mostly_vertical:
        ; Case B: delta_y > delta_x (mostly vertical)
        lda     delta_y
        sta     major_delta
        lda     delta_y+1
        sta     major_delta+1
        lda     delta_x
        sta     minor_delta
        lda     delta_x+1
        sta     minor_delta+1

        lda     sy_whole
        sta     major_step_whole
        lda     sy_whole+1
        sta     major_step_whole+1
        lda     #0
        sta     major_step_frac

@setup_line:
        ; line_count = major_delta + 1
        clc
        lda     major_delta
        adc     #1
        sta     line_count
        lda     major_delta+1
        adc     #0
        sta     line_count+1

        ; Compute start pixel address at (last_x, last_y)
        lda     last_y
        sta     MUL_A
        lda     last_y+1
        sta     MUL_A+1

        lda     #80
        sta     MUL_B
        lda     #0
        sta     MUL_B+1

        lda     last_x+1
        lsr     A
        sta     MUL_C+1
        lda     last_x
        ror     A
        sta     MUL_C
        lda     #0
        sta     MUL_C+2

        sta     MUL_TO_DST

        lda     #$80
        sta     DST_ADDR+2

        ; Step fractions and steps
        lda     last_x
        and     #1
        asl     A
        asl     A
        ora     major_step_frac
        sta     DST_FRAC

        lda     major_step_whole
        sta     DST_STEP
        lda     major_step_whole+1
        sta     DST_STEP+1

        lda     diag_step_whole
        sta     DST_LINE_DIAG_STEP
        lda     diag_step_whole+1
        sta     DST_LINE_DIAG_STEP+1

        lda     #$20
        sta     DST_LINE_DIAG_FRAC

        ; DST_LINE_ERROR = -(major_delta >> 1) in 24 bits
        ; If minor_delta == 0, use -1 ($FFFFFF) to prevent false diagonal steps
        lda     minor_delta
        ora     minor_delta+1
        bne     @calc_error
        lda     #$FF
        sta     DST_LINE_ERROR
        sta     DST_LINE_ERROR+1
        sta     DST_LINE_ERROR+2
        jmp     @set_mul

@calc_error:
        lda     major_delta+1
        lsr     A
        sta     tmp_g
        lda     major_delta
        ror     A
        sta     tmp_l

        lda     #0
        sec
        sbc     tmp_l
        sta     DST_LINE_ERROR
        lda     #0
        sbc     tmp_g
        sta     DST_LINE_ERROR+1
        lda     #0
        sbc     #0
        sta     DST_LINE_ERROR+2

@set_mul:
        lda     minor_delta
        sta     MUL_A
        lda     minor_delta+1
        sta     MUL_A+1

        lda     major_delta
        sta     MUL_B
        lda     major_delta+1
        sta     MUL_B+1

        ; Enable line mode
        lda     #(MODE_4BPP | MODE_LINE_BIT)
        sta     MODE

@line_loop:
        bit     DST_DATA
        lda     current_color
        sta     DST_DATA_INC
        lda     line_count
        bne     @dec_lo
        dec     line_count+1
@dec_lo:
        dec     line_count
        lda     line_count
        ora     line_count+1
        bne     @line_loop

        ; Line mode off
        lda     #MODE_4BPP
        sta     MODE

        lda     target_x
        sta     last_x
        lda     target_x+1
        sta     last_x+1
        lda     target_y
        sta     last_y
        lda     target_y+1
        sta     last_y+1
        rts

; ===========================================================================
; SETCOLOR p, n, r, g, b
; Sets color n of palette p to RGB555 value.
; ===========================================================================
exec_setcolor:
        sta     tmp_b
        jsr     pop_int_fp0
        sta     tmp_g
        jsr     pop_int_fp0
        sta     tmp_r
        jsr     pop_int_fp0
        sta     tmp_n
        jsr     pop_int_fp0
        sta     tmp_p

        lda     MODE
        pha
        lda     #MODE_8BPP
        sta     MODE

        ; Palette RAM base address: $B0800 + (p << 9) + (n << 1)
        lda     tmp_n
        asl     A
        sta     DST_ADDR
        lda     tmp_p
        asl     A
        adc     #$08
        sta     DST_ADDR+1
        lda     #$B0
        sta     DST_ADDR+2

        lda     #1
        sta     DST_STEP
        lda     #0
        sta     DST_STEP+1
        sta     DST_FRAC

        lda     tmp_b
        and     #$1F
        sta     tmp_b

        lda     tmp_g
        and     #$1F
        sta     tmp_g

        lda     tmp_r
        and     #$1F
        sta     tmp_r

        ; Low byte: ((G & 7) << 5) | B
        lda     tmp_g
        and     #$07
        asl     A
        asl     A
        asl     A
        asl     A
        asl     A
        ora     tmp_b
        sta     DST_DATA_INC

        ; High byte: ((R & 31) << 2) | (G >> 3)
        lda     tmp_g
        lsr     A
        lsr     A
        lsr     A
        sta     tmp_g
        lda     tmp_r
        asl     A
        asl     A
        ora     tmp_g
        sta     DST_DATA

        pla
        sta     MODE
        rts


