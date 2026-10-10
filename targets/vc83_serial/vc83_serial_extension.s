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
grmode_val:     .res 1
grmode_base:    .res 1
grmode_fmt:     .res 1
grmode_frm:     .res 1
draw_stride:    .res 2
draw_bpp:       .res 1
sx_frac:        .res 1
tmp_frac:       .res 1


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

; ===========================================================================
; ENTER string
; Closes channel 0 and opens string as channel 0 for read.
; ===========================================================================
exec_enter:
        ; Close channel 0
        lda     #0
        jsr     API_CLOSE

        ; Open string as channel 0 for read
        lda     #0
        sta     channel
        lda     #OPEN_READ
        jsr     open
        bcs     @fail
        rts

@fail:
        jmp     raise_io_error

; ===========================================================================
; GRMODE mode
; Configures VCGA graphics layers and manages the console lifecycle.
;
; Mode argument:
;   Bit 7:
;     If set on graphics/tilemap modes (e.g. +128): enables 4-line console
;     window at bottom of screen on Layer 2 (with transparent background)
;     and opens channel 0 to "C:". The console window is always tall in
;     the 640x400 frame (Part 7, bottom 64 lines).
;     If clear: disables Layer 2 and leaves channel 0 closed.
;   Bit 6:
;     0: Preset table modes (0..15)
;        0..3:   Console modes (Layer 2 full screen, Layer 3 disabled)
;                0: 80x25 text (tall, 640x400) - Default console mode
;                1: 40x25 text (2X, 640x400)
;                2: 90x60 text (1X, 720x480)
;                3: 45x30 text (2X, 720x480)
;        4..9:   Bitmap graphics modes (Layer 3 full screen, Palette 0)
;                4: 320x200x256 (2X, 8bpp, 640x400)
;                5: 320x200x16  (2X, 4bpp, 640x400)
;                6: 160x100x256 (4X, 8bpp, 640x400)
;                7: 160x100x16  (4X, 4bpp, 640x400)
;                8: 640x200x16  (tall, 4bpp, 640x400)
;                9: 360x240x16  (2X, 4bpp, 720x480)
;        10..15: Tilemap modes (Layer 3 full screen, Palette 0, Tile slot 0)
;                10: 40x25 tilemap 8bpp (2X, 8bpp, 640x400)
;                11: 40x25 tilemap 4bpp (2X, 4bpp, 640x400)
;                12: 80x50 tilemap 8bpp (1X, 8bpp, 640x400)
;                13: 80x50 tilemap 4bpp (1X, 4bpp, 640x400)
;                14: 45x30 tilemap 8bpp (2X, 8bpp, 720x480)
;                15: 45x30 tilemap 4bpp (2X, 4bpp, 720x480)
;     1: Algorithmic modes (64..127) on Layer 3
;        Bit 5: Frame (0 = 640x400, 1 = 720x480)
;        Bit 4: Kind (0 = Bitmap, 1 = Tilemap)
;        Bits 3:2: Scale (00 = 1X, 01 = 2X, 10 = 4X, 11 = tall)
;        Bits 1:0: Color depth (00 = 1bpp, 01 = 2bpp, 10 = 4bpp, 11 = 8bpp)
; ===========================================================================

mode_table_format:
        ; Console modes (0..3)
        ; Bit 7 selects frame: 0 = 640x400 (Frame 0), 1 = 720x480 (Frame 2)
        .byte   $1C     ; 0: 80x25 text (text, tall, 1bpp, 640x400)
        .byte   $14     ; 1: 40x25 text (text, 2X, 1bpp, 640x400)
        .byte   $10|$80 ; 2: 90x60 text (text, 1X, 1bpp, 720x480)
        .byte   $14|$80 ; 3: 45x30 text (text, 2X, 1bpp, 720x480)

        ; Bitmap graphics modes (4..9)
        .byte   $07     ; 4: 320x200x256 (bitmap, 2X, 8bpp, 640x400)
        .byte   $06     ; 5: 320x200x16  (bitmap, 2X, 4bpp, 640x400)
        .byte   $0B     ; 6: 160x100x256 (bitmap, 4X, 8bpp, 640x400)
        .byte   $0A     ; 7: 160x100x16  (bitmap, 4X, 4bpp, 640x400)
        .byte   $0E     ; 8: 640x200x16  (bitmap, tall, 4bpp, 640x400)
        .byte   $06|$80 ; 9: 360x240x16  (bitmap, 2X, 4bpp, 720x480)

        ; Tilemap modes (10..15)
        .byte   $17     ; 10: 40x25 tilemap 8bpp (tilemap, 2X, 8bpp, 640x400)
        .byte   $16     ; 11: 40x25 tilemap 4bpp (tilemap, 2X, 4bpp, 640x400)
        .byte   $13     ; 12: 80x50 tilemap 8bpp (tilemap, 1X, 8bpp, 640x400)
        .byte   $12     ; 13: 80x50 tilemap 4bpp (tilemap, 1X, 4bpp, 640x400)
        .byte   $17|$80 ; 14: 45x30 tilemap 8bpp (tilemap, 2X, 8bpp, 720x480)
        .byte   $16|$80 ; 15: 45x30 tilemap 4bpp (tilemap, 2X, 4bpp, 720x480)

grmode_charset_name:    .byte   "A:CHARSET.DAT"
grmode_charset_name_len = 13

grmode_console_name:    .byte   "C:"
grmode_console_name_len = 2

grmode_keyboard_name:   .byte   "K:"
grmode_keyboard_name_len = 2

exec_grmode:
        cpx     #0
        beq     :+
@arg_err:
        jmp     raise_out_of_range
:
        sta     grmode_val
        and     #$7F
        sta     grmode_base

        ; Check if algorithmic mode (bit 6 set)
        and     #$40
        beq     @preset_mode

        ; Algorithmic mode (64..127):
        lda     grmode_base
        and     #$1F                    ; format matches VCGALAYER bits 4:0
        sta     grmode_fmt

        lda     grmode_base
        and     #$20                    ; bit 5: 0 -> frame 0, 1 -> frame 2
        lsr
        lsr
        lsr
        lsr
        sta     grmode_frm
        jmp     @setup_layers

@preset_mode:
        lda     grmode_base
        cmp     #16
        bcs     @arg_err
        tax
        lda     #0
        sta     grmode_frm
        lda     mode_table_format, x
        bpl     :+
        lda     #2
        sta     grmode_frm
:
        lda     mode_table_format, x
        and     #$1F
        sta     grmode_fmt

@setup_layers:
        ; 1. Close channel 0
        lda     #0
        jsr     API_CLOSE

        ; 2. Always disable layers 0 and 1
        lda     #0
        sta     arg1            ; part 0 = disabled
        jsr     API_VCGALAYER
        lda     #1
        sta     arg1            ; part 0 = disabled
        jsr     API_VCGALAYER

        ; 3. Check if console mode (0..3) vs graphics/tilemap (4..15 or 64..127)
        lda     grmode_base
        cmp     #4
        bcs     @setup_graphics

        ; -------------------------------------------------------------
        ; Pure Console Mode (0..3)
        ; -------------------------------------------------------------
        ; Disable layer 3
        lda     #0
        sta     arg1
        lda     #3
        jsr     API_VCGALAYER

        ; Configure layer 2: full screen (part 1)
        lda     #$04            ; part 1 (full), frame in bits 1:0
        ora     grmode_frm
        sta     arg1
        lda     grmode_fmt
        sta     arg2
        lda     #0
        sta     arg3
        sta     arg4
        lda     #2
        jsr     API_VCGALAYER
        bcs     @err

        ; Overwrite Layer 2 attributes: tile set 7, palette 2, 1bpp, opaque
        ; (7 << 4) | (2 << 2) | 0 = $78
        lda     #$B0
        sta     BANK_SELECT_D
        lda     #$78
        sta     $D04D
        lda     #$E0
        sta     BANK_SELECT_D

        ; Load charset into tile slot 7
        jsr     load_font_slot7

        ; Open channel 0 to console on layer 2
        lda     #(2 << 5) | OPEN_READ_WRITE
        sta     arg1
        mvax    #grmode_console_name, arg2
        mva     #grmode_console_name_len, arg4
        lda     #0
        jsr     API_OPEN
        bcs     @err

        ; Default drawing state for text modes
        lda     #80
        sta     draw_stride
        lda     #0
        sta     draw_stride+1
        lda     #2
        sta     draw_bpp
        clc
        rts

@err:
        jmp     raise_out_of_range

        ; -------------------------------------------------------------
        ; Graphics / Tilemap Mode (4..15, 64..127)
        ; -------------------------------------------------------------
@setup_graphics:
        ; Configure layer 3: full screen (part 1)
        lda     #$04            ; part 1 (full), frame in bits 1:0
        ora     grmode_frm
        sta     arg1
        lda     grmode_fmt
        sta     arg2
        lda     #0
        sta     arg3
        sta     arg4
        lda     #3
        jsr     API_VCGALAYER
        bcs     @err

        ; Overwrite Layer 3 attributes: tile set 0, palette 3, bpp from format, opaque
        ; (0 << 4) | (3 << 2) | bpp = $0C | (grmode_fmt & 3)
        lda     grmode_fmt
        and     #$03
        sta     draw_bpp
        ora     #$0C
        sta     grmode_fmt
        lda     #$B0
        sta     BANK_SELECT_D
        lda     grmode_fmt
        sta     $D06D
        ; Read Layer 3 stride from $D06A / $D06B (stride in bytes)
        lda     $D06A
        sta     draw_stride
        lda     $D06B
        sta     draw_stride+1
        lda     #$E0
        sta     BANK_SELECT_D

        ; Check if console window (+128) requested
        lda     grmode_val
        bpl     @pure_graphics

        ; Mixed mode: console window at bottom on layer 2
        ; Region: part 7 (bottom 64), frame 00 (640x400)
        lda     #$1C            ; part 7 (bottom 64), frame 00
        sta     arg1
        lda     #$1C            ; text, tall, 1bpp
        sta     arg2
        lda     #0
        sta     arg3
        lda     #$FE            ; base = $FE00
        sta     arg4
        lda     #2
        jsr     API_VCGALAYER
        bcs     @err_graphics

        ; Overwrite Layer 2 attributes: tile set 7, palette 2, 1bpp, TRANSPARENT!
        ; $80 | (7 << 4) | (2 << 2) | 0 = $F8
        lda     #$B0
        sta     BANK_SELECT_D
        lda     #$F8
        sta     $D04D
        lda     #$E0
        sta     BANK_SELECT_D

        ; Load charset into tile slot 7
        jsr     load_font_slot7

        ; Re-open channel 0 to console on layer 2
        lda     #(2 << 5) | OPEN_READ_WRITE
        sta     arg1
        mvax    #grmode_console_name, arg2
        mva     #grmode_console_name_len, arg4
        lda     #0
        jsr     API_OPEN
        bcs     @err_graphics
        clc
        rts

@pure_graphics:
        ; Disable layer 2
        lda     #0
        sta     arg1
        lda     #2
        jsr     API_VCGALAYER

        ; Open channel 0 to K: for keyboard input
        lda     #OPEN_READ
        sta     arg1
        mvax    #grmode_keyboard_name, arg2
        mva     #grmode_keyboard_name_len, arg4
        lda     #0                      ; Channel 0
        jsr     API_OPEN
        clc
        rts

@err_graphics:
        jmp     raise_out_of_range


load_font_slot7:
        lda     dst_ptr
        pha
        lda     dst_ptr+1
        pha

        lda     #7
        jsr     API_CLOSE

        lda     #OPEN_READ
        sta     arg1
        mvax    #grmode_charset_name, arg2
        mva     #grmode_charset_name_len, arg4
        lda     #7                      ; Channel 7
        jsr     API_OPEN
        bcc     :+
        pla
        sta     dst_ptr+1
        pla
        sta     dst_ptr
        rts
:
        lda     #$A3
        sta     BANK_SELECT_A           ; Window A -> Tile RAM Bank 7

        lda     #<$A800
        sta     dst_ptr
        lda     #>$A800
        sta     dst_ptr+1

@load_font_loop:
        lda     #7
        jsr     API_GET
        bcs     @font_done
        ldy     #0
        sta     (dst_ptr), y
        inc     dst_ptr
        bne     :+
        inc     dst_ptr+1
:
        lda     dst_ptr+1
        cmp     #>$B000                 ; 2048 bytes: $A800 to $AFFF
        bcc     @load_font_loop

@font_done:
        lda     #7
        jsr     API_CLOSE

        lda     #0
        sta     BANK_SELECT_A

        pla
        sta     dst_ptr+1
        pla
        sta     dst_ptr
        rts


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
        lda     draw_bpp
        sta     MODE
        jsr     calc_pixel_addr

        lda     tmp_frac
        sta     DST_FRAC

        bit     DST_DATA
        lda     current_color
        sta     DST_DATA
        rts

calc_pixel_addr:
        ldx     draw_bpp
        cpx     #3
        beq     @bpp8
        cpx     #2
        beq     @bpp4
        cpx     #1
        beq     @bpp2

        ; 1 bpp (draw_bpp == 0): byte offset = last_x >> 3, frac = last_x & 7
        lda     last_x
        and     #7
        sta     tmp_frac
        lda     last_x+1
        lsr     A
        sta     MUL_C+1
        lda     last_x
        ror     A
        lsr     MUL_C+1
        ror     A
        lsr     MUL_C+1
        ror     A
        sta     MUL_C
        jmp     @calc_addr

@bpp2:
        ; 2 bpp (draw_bpp == 1): byte offset = last_x >> 2, frac = (last_x & 3) << 1
        lda     last_x
        and     #3
        asl     A
        sta     tmp_frac
        lda     last_x+1
        lsr     A
        sta     MUL_C+1
        lda     last_x
        ror     A
        lsr     MUL_C+1
        ror     A
        sta     MUL_C
        jmp     @calc_addr

@bpp4:
        ; 4 bpp (draw_bpp == 2): byte offset = last_x >> 1, frac = (last_x & 1) << 2
        lda     last_x
        and     #1
        asl     A
        asl     A
        sta     tmp_frac
        lda     last_x+1
        lsr     A
        sta     MUL_C+1
        lda     last_x
        ror     A
        sta     MUL_C
        jmp     @calc_addr

@bpp8:
        ; 8 bpp (draw_bpp == 3): byte offset = last_x, frac = 0
        lda     #0
        sta     tmp_frac
        lda     last_x
        sta     MUL_C
        lda     last_x+1
        sta     MUL_C+1

@calc_addr:
        lda     #0
        sta     MUL_C+2

        lda     last_y
        sta     MUL_A
        lda     last_y+1
        sta     MUL_A+1

        lda     draw_stride
        sta     MUL_B
        lda     draw_stride+1
        sta     MUL_B+1

        sta     MUL_TO_DST

        lda     #$80
        sta     DST_ADDR+2
        rts

sx_pos_whole_l: .byte 0, 0, 0, 1
sx_pos_whole_h: .byte 0, 0, 0, 0
sx_pos_frac:    .byte $08, $10, $20, $00

sx_neg_whole_l: .byte $FF, $FF, $FF, $FF
sx_neg_whole_h: .byte $FF, $FF, $FF, $FF
sx_neg_frac:    .byte $38, $30, $20, $00

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

        ; Calculate delta_x and sx
        sec
        lda     target_x
        sbc     last_x
        sta     delta_x
        lda     target_x+1
        sbc     last_x+1
        sta     delta_x+1
        bcs     @x_pos

        ; Negative X: delta_x = -delta_x
        lda     #0
        sec
        sbc     delta_x
        sta     delta_x
        lda     #0
        sbc     delta_x+1
        sta     delta_x+1

        ldx     draw_bpp
        lda     sx_neg_whole_l, x
        sta     sx_whole
        lda     sx_neg_whole_h, x
        sta     sx_whole+1
        lda     sx_neg_frac, x
        sta     sx_frac
        jmp     @calc_dy

@x_pos:
        ldx     draw_bpp
        lda     sx_pos_whole_l, x
        sta     sx_whole
        lda     sx_pos_whole_h, x
        sta     sx_whole+1
        lda     sx_pos_frac, x
        sta     sx_frac

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

        ; Negative Y: delta_y = -delta_y, sy_whole = -draw_stride
        lda     #0
        sec
        sbc     delta_y
        sta     delta_y
        lda     #0
        sbc     delta_y+1
        sta     delta_y+1

        lda     #0
        sec
        sbc     draw_stride
        sta     sy_whole
        lda     #0
        sbc     draw_stride+1
        sta     sy_whole+1
        jmp     @calc_diag

@y_pos:
        lda     draw_stride
        sta     sy_whole
        lda     draw_stride+1
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
        lda     sx_frac
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
        jsr     calc_pixel_addr

        ; Step fractions and steps
        lda     tmp_frac
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

        lda     sx_frac
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
        lda     draw_bpp
        ora     #MODE_LINE_BIT
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
        lda     draw_bpp
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


