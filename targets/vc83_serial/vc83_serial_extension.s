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
tmp_l:          .res 1
tmp_h:          .res 1
grmode_val:     .res 1
grmode_base:    .res 1
grmode_fmt:     .res 1
grmode_frm:     .res 1
draw_stride:    .res 2
draw_bpp:       .res 1
sx_frac:        .res 1
tmp_frac:       .res 1
sync_last_frame: .res 1


.segment "CODE"

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
        jsr     open_channel
        bcs     @open_err
        rts

@open_type_mismatch:
        jmp     raise_type_mismatch

@open_err:
        raise   ERR_IO_ERROR

; Opens a channel using OS API_OPEN ($E006).
; S0 = filename string, length in (BC)
; A = open mode
; channel = channel index (0..7)
open_channel:
        sta     arg1                    ; Mode in arg1
        ldy     #0
        lda     (BC), y                 ; Length
        sta     path_len                ; Length in path_len
        lda     S0
        sta     path_ptr                ; String ptr low
        lda     S0+1
        sta     path_ptr+1              ; String ptr high
        lda     channel
        and     #$07                    ; Channel 0..7
        jsr     API_OPEN
        rts

; CLOSE [#channel]
exec_close:
        lda     channel
        and     #$07
        jsr     API_CLOSE
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
        lda     B                       ; Command in arg1
        sta     arg1
        lda     BC
        sta     arg2
        lda     BC+1
        sta     arg3
        lda     DE
        sta     arg4
        lda     channel
        and     #$07
        jsr     API_XIO
        bcs     @xio_err
        rts

@xio_type_mismatch:
        jmp     raise_type_mismatch

@xio_err:
        raise   ERR_IO_ERROR

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
        sta     path_len
        lda     S0
        sta     path_ptr
        lda     S0+1
        sta     path_ptr+1
        lda     #4                      ; OPEN_DIRECTORY
        sta     arg1
        lda     #7                      ; Channel 7
        jsr     API_OPEN
        bcc     @dir_read_loop

        ; Open failed: fail immediately without closing channel 7
        jmp     raise_io_error

@dir_read_loop:
        lda     #<dir_record
        sta     io_ptr
        lda     #>dir_record
        sta     io_ptr+1
        stz     io_seg
        lda     #15                     ; DIR_RECORD_SIZE
        sta     io_len
        stz     io_len+1
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
; SOURCE string
; Opens string as channel 7 for read and sets default_channel to 7.
; ===========================================================================
exec_source:
        lda     #7                      ; Channel 7 is reserved for SOURCE
        sta     channel
        jsr     API_CLOSE               ; Close channel 7 in case already open
        lda     #OPEN_READ              ; Open mode: read
        jsr     open_channel
        bcs     @fail                   ; If open failed then raise error
        lda     #7
        sta     default_channel         ; Direct subsequent input to channel 7
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
;        Bits 1:0: Color depth (00 = 8bpp, 01 = 4bpp, 10 = 2bpp, 11 = 1bpp)
; ===========================================================================

mode_table_format:
        ; Console modes (0..3)
        ; Bit 7 selects frame: 0 = 640x400 (Frame 0), 1 = 720x480 (Frame 2)
        .byte   $1F     ; 0: 80x25 text (text, tall, 1bpp, 640x400)
        .byte   $17     ; 1: 40x25 text (text, 2X, 1bpp, 640x400)
        .byte   $13|$80 ; 2: 90x60 text (text, 1X, 1bpp, 720x480)
        .byte   $17|$80 ; 3: 45x30 text (text, 2X, 1bpp, 720x480)

        ; Bitmap graphics modes (4..9)
        .byte   $04     ; 4: 320x200x256 (bitmap, 2X, 8bpp, 640x400)
        .byte   $05     ; 5: 320x200x16  (bitmap, 2X, 4bpp, 640x400)
        .byte   $08     ; 6: 160x100x256 (bitmap, 4X, 8bpp, 640x400)
        .byte   $09     ; 7: 160x100x16  (bitmap, 4X, 4bpp, 640x400)
        .byte   $0D     ; 8: 640x200x16  (bitmap, tall, 4bpp, 640x400)
        .byte   $05|$80 ; 9: 360x240x16  (bitmap, 2X, 4bpp, 720x480)

        ; Tilemap modes (10..15)
        .byte   $14     ; 10: 40x25 tilemap 8bpp (tilemap, 2X, 8bpp, 640x400)
        .byte   $15     ; 11: 40x25 tilemap 4bpp (tilemap, 2X, 4bpp, 640x400)
        .byte   $10     ; 12: 80x50 tilemap 8bpp (tilemap, 1X, 8bpp, 640x400)
        .byte   $11     ; 13: 80x50 tilemap 4bpp (tilemap, 1X, 4bpp, 640x400)
        .byte   $14|$80 ; 14: 45x30 tilemap 8bpp (tilemap, 2X, 8bpp, 720x480)
        .byte   $15|$80 ; 15: 45x30 tilemap 4bpp (tilemap, 2X, 4bpp, 720x480)

grmode_charset_name:    .byte   "A:CHARSET.DAT"
grmode_charset_name_len = 13

grmode_console_name:    .byte   "C:"
grmode_console_name_len = 2

grmode_keyboard_name:   .byte   "K:"
grmode_keyboard_name_len = 2

exec_grmode:
        cpx     #0
        beq     @arg_ok
@arg_err:
        jmp     raise_out_of_range
@arg_ok:
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
        bpl     @format_frame0
        lda     #2
        sta     grmode_frm
@format_frame0:
        lda     mode_table_format, x
        and     #$1F
        sta     grmode_fmt

@setup_layers:
        ; Disable layers 0 and 1
        lda     #0
        sta     arg1            ; part 0 = disabled
        jsr     API_VCGALAYER
        lda     #1
        sta     arg1            ; part 0 = disabled
        jsr     API_VCGALAYER

        ; Disable all 32 sprites
        lda     #$B0
        sta     BANK_SELECT_D
        ldx     #0
        clc
@clear_sprites:
        stz     $D106, x
        txa
        adc     #8
        tax
        bne     @clear_sprites

        ; Check if console mode (0..3) vs graphics/tilemap (4..15 or 64..127)
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
        ; (7 << 4) | (2 << 2) | 3 = $7B
        lda     #$B0
        sta     BANK_SELECT_D
        lda     #$7B
        sta     $D04D
        lda     #$E0
        sta     BANK_SELECT_D

        ; Load charset into tile slot 7
        jsr     load_font_slot7

        ; If channel 0 is open to other device (e.g. H:), leave it alone
        jsr     is_channel_0_other      ; Check if channel 0 is open to other device
        bcs     @text_done              ; Leave channel 0 alone if other device

        lda     #0                      ; Close existing console channel 0
        jsr     API_CLOSE

        lda     #(2 << 5) | OPEN_READ_WRITE
        sta     arg1
        mvax    #grmode_console_name, path_ptr
        mva     #grmode_console_name_len, path_len
        lda     #0
        jsr     API_OPEN
        bcs     @err                    ; If open failed then raise error

@text_done:
        ; Default drawing state for text modes
        lda     #80
        sta     draw_stride
        lda     #0
        sta     draw_stride+1
        lda     #MODE_8BPP
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
        and     #$10            ; Check if tilemap mode (bit 4 set)
        beq     @bitmap_bpp
        lda     #MODE_8BPP      ; Tilemap VRAM is always 8 bits per tile
        beq     @set_draw_bpp
@bitmap_bpp:
        lda     grmode_fmt
        and     #$03
@set_draw_bpp:
        sta     draw_bpp
        lda     grmode_fmt
        and     #$03
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

        ; If channel 0 is open to other device, leave channel 0 alone and disable Layer 2
        jsr     is_channel_0_other      ; Check if channel 0 is open to other device
        bcc     @setup_l2_console       ; Configure console window if not other device

        ; Disable layer 2
        lda     #0                      ; Layer mode 0 = disabled
        sta     arg1
        lda     #2
        jsr     API_VCGALAYER           ; Disable layer 2
        clc
        rts

@setup_l2_console:
        ; Channel 0 is open to C:. Always configure Layer 2 console window at bottom
        ; Region: part 7 (bottom 64), frame 00 (640x400)
        lda     #$1C            ; part 7 (bottom 64), frame 00
        sta     arg1
        lda     #$1F            ; text, tall, 1bpp
        sta     arg2
        lda     #0
        sta     arg3
        lda     #$FE            ; base = $FE00
        sta     arg4
        lda     #2
        jsr     API_VCGALAYER
        bcs     @err_graphics

        ; Overwrite Layer 2 attributes: tile set 7, palette 2, 1bpp, TRANSPARENT!
        ; $80 | (7 << 4) | (2 << 2) | 3 = $FB
        lda     #$B0
        sta     BANK_SELECT_D
        lda     #$FB
        sta     $D04D
        lda     #$E0
        sta     BANK_SELECT_D

        ; Load charset into tile slot 7
        jsr     load_font_slot7

        ; Close channel 0 and re-open to console on layer 2
        lda     #0                      ; Close existing channel 0
        jsr     API_CLOSE

        lda     #(2 << 5) | OPEN_READ_WRITE
        sta     arg1
        mvax    #grmode_console_name, path_ptr
        mva     #grmode_console_name_len, path_len
        lda     #0
        jsr     API_OPEN
        bcs     @err_graphics

        ; Check if console window (+128) requested
        lda     grmode_val
        bmi     @window_visible         ; Bit 7 is 1: keep console window visible

        ; Pure graphics: hide Layer 2 and cursor
        lda     #$B0                    ; Select VCGA register bank
        sta     BANK_SELECT_D
        stz     $D04C                   ; Layer 2 mode = 0 (hidden)
        stz     $D1FE                   ; Disable Sprite 31 cursor
        lda     #$E0                    ; Restore standard bank
        sta     BANK_SELECT_D

@window_visible:
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
        mvax    #grmode_charset_name, path_ptr
        mva     #grmode_charset_name_len, path_len
        lda     #7                      ; Channel 7
        jsr     API_OPEN
        bcc     @open_font_ok
        pla
        sta     dst_ptr+1
        pla
        sta     dst_ptr
        rts
@open_font_ok:
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
        bne     @no_ptr_carry
        inc     dst_ptr+1
@no_ptr_carry:
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

; ===========================================================================
; COLORAT(x, y)
; Returns the pixel or tile value at (x, y).
; PROLOG_POP_INT pops y into AX.
; ===========================================================================
fun_colorat:
        sta     target_y
        stx     target_y+1
        sta     last_y
        stx     last_y+1
        jsr     pop_int_fp0             ; Pop x into AX
        sta     target_x
        stx     target_x+1
        sta     last_x
        stx     last_x+1

        lda     draw_bpp
        sta     MODE
        jsr     calc_pixel_addr

        lda     tmp_frac
        sta     DST_FRAC

        lda     DST_DATA
        ldx     #0
        rts

calc_pixel_addr:
        ldx     draw_bpp
        beq     @bpp8                   ; 0 = 8 bpp
        cpx     #1
        beq     @bpp4                   ; 1 = 4 bpp
        cpx     #2
        beq     @bpp2                   ; 2 = 2 bpp

        ; 1 bpp (draw_bpp == 3): byte offset = last_x >> 3, frac = last_x & 7
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
        ; 2 bpp (draw_bpp == 2): byte offset = last_x >> 2, frac = (last_x & 3) << 1
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
        ; 4 bpp (draw_bpp == 1): byte offset = last_x >> 1, frac = (last_x & 1) << 2
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
        ; 8 bpp (draw_bpp == 0): byte offset = last_x, frac = 0
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

; Line mode step tables indexed by draw_bpp: 0=8bpp, 1=4bpp, 2=2bpp, 3=1bpp
sx_pos_whole_l: .byte 1, 0, 0, 0
sx_pos_whole_h: .byte 0, 0, 0, 0
sx_pos_frac:    .byte $00, $20, $10, $08

sx_neg_whole_l: .byte $FF, $FF, $FF, $FF
sx_neg_whole_h: .byte $FF, $FF, $FF, $FF
sx_neg_frac:    .byte $00, $20, $30, $38

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

        ; Enable line mode first (resets step and fraction registers)
        lda     draw_bpp
        ora     #MODE_LINE_BIT
        sta     MODE

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
        sta     tmp_h
        lda     major_delta
        ror     A
        sta     tmp_l

        lda     #0
        sec
        sbc     tmp_l
        sta     DST_LINE_ERROR
        lda     #0
        sbc     tmp_h
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
        jsr     @read_component
        jsr     @read_component
        jsr     @read_component         ; Leaves n in A
        lsr     E                       ; 16th shift: clears bit 15 of DE and shifts into D
        ror     D
        pha                             ; Save n (color index)
        jsr     pop_int_fp0             ; A = p (palette index)
        asl     A
        ora     #$08
        sta     DST_ADDR+1
        pla                             ; A = n
        asl     A
        sta     DST_ADDR
        bcc     @no_carry
        inc     DST_ADDR+1
@no_carry:
        stz     MODE
        mva     #$B0, DST_ADDR+2
        mva     D, DST_DATA
        inc     DST_ADDR
        mva     E, DST_DATA
        rts

@read_component:
        ldy     #5                      ; 5 bits per component
@bit_loop:
        lsr     A
        ror     E
        ror     D
        dey
        bne     @bit_loop
        jmp     pop_int_fp0

; ===========================================================================
; SYNC n
; Synchronizes execution to the VCGA frame counter.
; n = 0: resets sync baseline to current frame counter.
; n = 1..127: waits until frame counter reaches baseline + n.
; ===========================================================================
exec_sync:
        cpx     #0                              ; Validate integer fits in 8 bits
        bne     @out_of_range
        cmp     #128                            ; Limit to max 127 frames (~2.1s)
        bcs     @out_of_range

        clc
        adc     sync_last_frame
        sta     sync_last_frame

        ; Point SRC_ADDR to VCGA Frame Count [7:0] at $B0087
        stz     MODE
        mvax    #$0087, SRC_ADDR
        mva     #$B0, SRC_ADDR+2

@spin:
        lda     sync_last_frame
        sec
        sbc     SRC_DATA
        beq     @done
        bpl     @spin

        ; Target is overdue (in the past); reset baseline to current frame
        mva     SRC_DATA, sync_last_frame

@done:
        rts

@out_of_range:
        jmp     raise_out_of_range


; ===========================================================================
; POKE24 addr, val
; DPOKE24 addr, val
; Writes a single byte or 16-bit word to a 24-bit address using the bus
; accelerator DST registers.
; PROLOG_POP_INT pops val into AX; addr is popped from the value stack.
; ===========================================================================
exec_dpoke24:
        jsr     exec_poke24
        mva     E, DST_DATA             ; Write high byte to incremented address
        rts

exec_poke24:
        stax    DE                      ; Save val in DE
        jsr     pop_fp0                 ; Pop 24-bit addr into FP0
        jsr     set_dst_addr_from_fp0   ; Set DST_ADDR and step = 1
        mva     D, DST_DATA_INC         ; Write low byte, advance pointer by 1
        rts

; ===========================================================================
; PEEK24(addr)
; DPEEK24(addr)
; Reads a single byte or 16-bit word from a 24-bit address using the bus
; accelerator DST registers.
; PROLOG_POP_FP pops addr into FP0.
; ===========================================================================
fun_dpeek24:
        jsr     fun_peek24              ; Read low byte, advance pointer by 1
        ldx     DST_DATA                ; Read high byte into X
        rts

fun_peek24:
        jsr     set_dst_addr_from_fp0   ; Set DST_ADDR and step = 1
        lda     DST_DATA_INC            ; Read low byte, advance pointer by 1
        ldx     #0                      ; Zero-extend to 16-bit AX
        rts

set_dst_addr_from_fp0:
        jsr     truncate_fp_to_int32    ; Truncate FP0 to 32-bit int in FP0t
        ldx     #2                      ; Copy 24-bit address to DST_ADDR
@copy:  lda     FP0t,x
        sta     DST_ADDR,x
        dex
        bpl     @copy

        stz     MODE                    ; Set 8bpp mode, DST_STEP = 1, DST_FRAC = 0
        rts

; ===========================================================================
; SPIOPEN port, cs [, mode [, clk_div]]
; Configures and enables the SPI controller on the specified I/O port.
; ===========================================================================
exec_spiopen:
        jsr     eval_byte_arg           ; Evaluate port (0..15)
        pha                             ; Save port
        jsr     eval_next_byte_arg      ; Skip comma, evaluate CS line (0..3)
        cmp     #4                      ; Verify CS is in range 0..3
        bcs     io_out_of_range
        sta     tmp_l                   ; Save CS line
        stz     tmp_h                   ; Default mode = 0
        jsr     peek_byte               ; Optional mode argument present?
        beq     @default_clk
        jsr     eval_next_byte_arg      ; Skip comma, evaluate mode (0..7)
        cmp     #8                      ; Verify mode is in range 0..7
        bcs     io_out_of_range
        asl     A                       ; Shift mode into bits 3:1
        sta     tmp_h
        jsr     peek_byte               ; Optional clk_div argument present?
        beq     @default_clk
        jsr     eval_next_byte_arg      ; Skip comma, evaluate clk_div (0..255)
        bra     @apply

@default_clk:
        lda     #2                      ; Default clk_div = 2 (6.75 MHz)
@apply:
        sta     arg2                    ; Save clk_div
        pla                             ; Restore port
        ldx     #CAP_SPI
        jsr     check_io_port           ; Validate port and set up io_ptr
        ldy     #IO_SPI_CTRL
        lda     #0
        sta     (io_ptr),y              ; Disable SPI so CS select writes directly
        ldy     #IO_SPI_CLK_DIV
        lda     arg2
        sta     (io_ptr),y              ; Write IO_SPI_CLK_DIV ($22)
        iny                             ; Advance to IO_SPI_CS_SELECT ($23)
        lda     tmp_l
        sta     (io_ptr),y              ; Set idle CS line with cs_enable = 0
        ldy     #IO_SPI_CTRL
        lda     tmp_h
        ora     #$01                    ; Combine (mode << 1) with spi_en
        sta     (io_ptr),y              ; Enable SPI controller ($20)
        rts

; ===========================================================================
; I2COPEN port, addr [, clk_div]
; Configures and enables the I2C controller on the specified I/O port.
; ===========================================================================
exec_i2copen:
        jsr     eval_byte_arg           ; Evaluate port (0..15)
        pha                             ; Save port
        jsr     eval_next_byte_arg      ; Skip comma, evaluate target address
        bmi     io_out_of_range         ; Verify target address is 0..127
        sta     tmp_l                   ; Save target address
        jsr     peek_byte               ; Optional clk_div argument present?
        beq     @default_clk
        jsr     eval_next_byte_arg      ; Skip comma, evaluate clk_div (0..255)
        bra     @apply

@default_clk:
        lda     #67                     ; Default clk_div = 67 (~100 kHz)
@apply:
        sta     arg2                    ; Save clk_div
        pla                             ; Restore port
        ldx     #CAP_I2C
        jsr     check_io_port           ; Validate port and set up io_ptr
        ldy     #IO_I2C_CLK_DIV
        lda     arg2
        sta     (io_ptr),y              ; Write IO_I2C_CLK_DIV ($32)
        iny                             ; Advance to IO_I2C_ADDR ($33)
        lda     tmp_l
        sta     (io_ptr),y              ; Write IO_I2C_ADDR ($33)
        ldy     #IO_I2C_CTRL
        lda     #1
        sta     (io_ptr),y              ; Enable I2C controller ($30)
        rts

io_out_of_range:
        jmp     raise_out_of_range

; ===========================================================================
; BUF$(b1 [, b2, ...])
; Packs byte arguments (0..255) into a newly allocated string using the 6502
; hardware stack.
; ===========================================================================
fun_buf_s:
        lda     #0                      ; Initialize byte count on stack
        pha
@loop:
        jsr     eval_byte_arg           ; Evaluate next byte argument (0..255)
        tay                             ; Save byte in Y
        pla                             ; Pull current byte count
        inc     A                       ; Increment count
        phy                             ; Push byte onto hardware stack
        pha                             ; Push updated count on top
        tsx                             ; Check hardware stack pointer
        bpl     @stack_error            ; Error if stack grew below $80
        jsr     peek_byte               ; Check for TOK_COMMA (more arguments)
        cmp     #TOK_COMMA
        bne     @done                   ; TOK_RPAREN -> finished
        inc     line_pos                ; Skip comma
        bra     @loop

@done:
        pla                             ; Pull total byte count
        jsr     string_alloc_for_copy   ; Allocate string, dst_ptr = data, Y = len
@copy:
        dey
        pla                             ; Pull bytes in reverse order (Y-1 down to 0)
        sta     (dst_ptr),y
        tya
        bne     @copy
        rts

@stack_error:
        jmp     raise_stack

; ===========================================================================
; SPI / I2C Helper Routines
; ===========================================================================
check_io_port:
        cmp     #16                     ; Verify port is in range 0..15
        bcs     io_out_of_range
        ora     #$D0                    ; Map to Window D page ($D0..$DF)
        sta     io_ptr+1
        stz     io_ptr
        mva     #$E0, BANK_SELECT_D     ; Select I/O bank ($E0000) in Window D
        txa                             ; Capability mask in A
        and     (io_ptr)                ; Check IO_CAPABILITIES at offset $00
        beq     io_error                ; Capability not supported -> I/O error
        rts

call_spixfer:
        jsr     API_SPIXFER
        bcs     io_error
        rts

call_i2cxfer:
        jsr     API_I2CXFER
        bcs     io_error
        rts

; ===========================================================================
; EXEC path
; Calls OS API_EXEC ($E000) to load and execute a binary program.
; PROLOG_POP_STRING pops path into S0 with length in A.
; ===========================================================================
exec_exec:
        sta     path_len                ; Store path length
        mvax    S0, path_ptr            ; Store path pointer
        jsr     API_EXEC                ; Load and execute (only returns on error)
io_error:
        jmp     raise_io_error

eval_next_string_arg:
        inc     line_pos                ; Skip TOK_COMMA
        jsr     evaluate_expression     ; Evaluate string expression -> S0
        lda     expr_type               ; Verify expression is a string
        beq     io_type_mismatch
        rts

eval_next_int_arg:
        inc     line_pos                ; Skip TOK_COMMA
        jsr     evaluate_expression     ; Evaluate numeric expression -> FP0
require_int_fp0:
        lda     expr_type               ; Verify expression is numeric
        bne     io_type_mismatch
        jmp     truncate_fp_to_int      ; Convert FP0 to 16-bit int in AX

eval_next_byte_arg:
        inc     line_pos                ; Skip TOK_COMMA
eval_byte_arg:
        jsr     evaluate_expression     ; Evaluate numeric expression -> FP0
require_byte_fp0:
        jsr     require_int_fp0         ; Convert numeric FP0 to 16-bit int in AX
require_byte_ax:
        cpx     #0                      ; Verify value is in range 0..255
        bne     io_out_of_range
        rts

pop_byte_fp0:
        jsr     pop_int_fp0             ; Pop numeric value and truncate to AX
        bra     require_byte_ax

prepare_write_transfer:
        stx     arg1                    ; Store transfer flags in arg1
        jsr     set_io_buffer_s0        ; Set io_ptr = S0, io_len = A
        jmp     pop_byte_fp0            ; Pop port (0..255) into A

set_io_buffer_s0:
        sta     io_len                  ; Set low byte of transfer length
        stz     io_len+1                ; High byte of transfer length = 0
        mvax    S0, io_ptr              ; Point io_ptr to string data buffer
        rts

alloc_copy_s0:
        jsr     push_string_s0          ; Push source string on value stack
        lday    S0
        jsr     load_s0                 ; A = source string length
        jsr     string_alloc_for_copy   ; Allocate string (string_ptr), dst_ptr = data
        jsr     pop_string_s0           ; Pop relocated source string: S0 = data
        tay                             ; Length in Y
        ldax    S0                      ; Source data pointer in AX
        jmp     copy_y_from             ; Copy Y bytes from AX to dst_ptr

; ===========================================================================
; SPIWRITE port, tx$
; I2CWRITE port, tx$
; Transmits tx$ as a complete SPI or I2C write transaction.
; PROLOG_POP_STRING pops tx$ into S0 (data ptr) and A (length); port is on stack.
; ===========================================================================
exec_spiwrite:
        ldx     #SPI_WRITE_ONLY         ; Discard received bytes, release CS
        jsr     prepare_write_transfer  ; Set io_ptr/io_len, arg1 = X, pop port
        jmp     call_spixfer

exec_i2cwrite:
        ldx     #0                      ; Write with START and STOP
        jsr     prepare_write_transfer  ; Set io_ptr/io_len, arg1 = X, pop port
        jmp     call_i2cxfer

; ===========================================================================
; SPACE$(len)
; STRING$(len, byte)
; Returns a string of len bytes (0..255) filled with space ($20) or byte (0..255).
; For SPACE$, PROLOG_POP_INT pops len into AX.
; For STRING$, PROLOG_POP_INT pops byte into AX; len is on the value stack.
; ===========================================================================
fun_space_s:
        jsr     require_byte_ax         ; Verify length in AX is 0..255
        ldy     #' '                    ; Fill byte = space ($20)
        phy                             ; Save fill byte
        bra     string_fill

fun_string_s:
        jsr     require_byte_ax         ; Verify fill byte is 0..255
        pha                             ; Save fill byte
        jsr     pop_byte_fp0            ; Pop length (0..255) into A
string_fill:
        jsr     string_alloc_for_copy   ; Allocate string, dst_ptr = data, Y = len
        pla                             ; Restore fill byte
        cpy     #0                      ; Empty string?
        beq     @done
@fill:
        dey
        sta     (dst_ptr),y             ; Fill character buffer with byte
        bne     @fill
@done:
        rts

io_type_mismatch:
        jmp     raise_type_mismatch

; ===========================================================================
; SPI$(port, [cmd$,] tx$)
; Executes a full-duplex SPI exchange (2 args) or command-then-exchange (3 args)
; and returns the received bytes as a string.
; ===========================================================================
fun_spi_s:
        jsr     eval_byte_arg           ; Evaluate port (0..15)
        pha                             ; Save port
        jsr     eval_next_string_arg    ; Skip comma, evaluate 2nd arg
        jsr     peek_byte
        cmp     #TOK_COMMA              ; Check if 3rd argument is present
        bne     @two_args

        ; 3 arguments: SPI$(port, cmd$, tx$)
        jsr     push_string_s0          ; Push cmd$ on value stack (GC safe)
        jsr     eval_next_string_arg    ; Skip comma, evaluate tx$
        jsr     alloc_copy_s0           ; Allocate copy of tx$ at string_ptr
        jsr     pop_string_s0           ; Pop cmd$: S0 = data ptr, A = length
        beq     @exchange               ; Skip Phase 1 if cmd$ is empty
        jsr     set_io_buffer_s0        ; io_ptr = S0, io_len = A
        mva     #SPI_WRITE_ONLY | SPI_CS_HOLD, arg1
        tsx
        lda     $101,x                  ; Read port from stack
        jsr     call_spixfer            ; Phase 1: write cmd$ and hold CS low
        bra     @exchange

@two_args:
        ; 2 arguments: SPI$(port, tx$)
        jsr     alloc_copy_s0           ; Allocate copy of tx$ at string_ptr

@exchange:
        lday    string_ptr
        jsr     load_s0                 ; S0 = string_ptr + 1, A = length
        jsr     set_io_buffer_s0        ; io_ptr = S0, io_len = length
        stz     arg1                    ; Full-duplex exchange, release CS
        pla                             ; Restore port
        jmp     call_spixfer


; ===========================================================================
; I2C$(port, [tx$,] rx_len)
; Executes an I2C read (2 args) or write-then-repeated-start-read (3 args)
; and returns the received bytes as a string.
; ===========================================================================
fun_i2c_s:
        jsr     eval_byte_arg           ; Evaluate port (0..15)
        pha                             ; Save port
        inc     line_pos                ; Skip comma
        jsr     evaluate_expression     ; Evaluate 2nd arg (rx_len or tx$)
        jsr     peek_byte
        cmp     #TOK_COMMA              ; Check if 3rd argument is present
        beq     @three_args

        ; 2 arguments: I2C$(port, rx_len)
        jsr     require_byte_fp0        ; Verify rx_len is numeric 0..255
        jsr     string_alloc_for_copy   ; Allocate RX string at string_ptr
        bra     @read_phase

@three_args:
        ; 3 arguments: I2C$(port, tx$, rx_len)
        lda     expr_type               ; Verify tx$ is a string
        beq     io_type_mismatch
        jsr     push_string_s0          ; Push tx$ on value stack (GC safe)
        jsr     eval_next_byte_arg      ; Skip comma, evaluate rx_len (0..255)
        jsr     string_alloc_for_copy   ; Allocate RX string at string_ptr
        jsr     pop_string_s0           ; Pop tx$: S0 = data ptr, A = length
        beq     @read_phase             ; Skip write phase if tx$ is empty
        jsr     set_io_buffer_s0        ; io_ptr = S0, io_len = A
        mva     #I2C_NO_STOP, arg1      ; Write tx$ without STOP
        tsx
        lda     $101,x                  ; Read port from stack
        jsr     call_i2cxfer            ; Phase 1: START + addr+W + tx$

@read_phase:
        lday    string_ptr
        jsr     load_s0                 ; S0 = string_ptr + 1, A = rx_len
        jsr     set_io_buffer_s0        ; io_ptr = S0, io_len = rx_len
        mva     #I2C_READ, arg1         ; Read rx_len bytes with STOP at end
        pla                             ; Restore port
        jmp     call_i2cxfer

; ===========================================================================
; SPICLOSE port
; I2CCLOSE port
; Disables the SPI or I2C controller on the specified I/O port.
; PROLOG_POP_INT pops port into AX.
; ===========================================================================
exec_spiclose:
        ldy     #IO_SPI_CTRL
        jsr     require_byte_ax         ; Verify port high byte is 0
        ldx     #CAP_SPI
        bne     io_close                ; Unconditional

exec_i2cclose:
        ldy     #IO_I2C_CTRL
        jsr     require_byte_ax         ; Verify port high byte is 0
        ldx     #CAP_I2C
io_close:
        jsr     check_io_port           ; Validate port and set up io_ptr
        lda     #0
        sta     (io_ptr),y              ; Disable controller
        rts

; ===========================================================================
; PORTDIR port, dir
; Sets the 16-bit GPIO direction mask (0 = input, 1 = output).
; PROLOG_POP_INT pops dir into AX; port is on the value stack.
; ===========================================================================
exec_portdir:
        stax    DE                      ; Save 16-bit direction mask in DE
        jsr     pop_byte_fp0            ; Pop port (0..255) into A
        ldx     #CAP_GPIO
        jsr     check_io_port           ; Validate port and set up io_ptr
        ldy     #IO_GPIO_DIR_0
        lda     D
        sta     (io_ptr),y              ; Write Group 0 direction ($12)
        ldy     #IO_GPIO_DIR_1
        lda     E
        sta     (io_ptr),y              ; Write Group 1 direction ($1A)
        rts

; ===========================================================================
; PORTWRITE port, value [, mask]
; Writes to the 16-bit GPIO output registers, optionally masked by mask.
; ===========================================================================
exec_portwrite:
        jsr     eval_byte_arg           ; Evaluate port (0..15)
        pha                             ; Save port
        jsr     eval_next_int_arg       ; Skip comma, evaluate 16-bit value
        stax    DE                      ; Save value in DE
        lda     #$FF
        sta     tmp_l                   ; Default mask = $FFFF
        sta     tmp_h
        jsr     peek_byte               ; Optional mask argument present?
        beq     @apply
        jsr     eval_next_int_arg       ; Skip comma, evaluate 16-bit mask
        stax    tmp_l                   ; Save mask in tmp_l/tmp_h
@apply:
        pla                             ; Restore port
        ldx     #CAP_GPIO
        jsr     check_io_port           ; Validate port and set up io_ptr
        ldy     #IO_GPIO_OUT_0
        lda     (io_ptr),y              ; Read Group 0 output ($10)
        eor     D
        and     tmp_l
        eor     (io_ptr),y
        sta     (io_ptr),y              ; Write updated Group 0 output ($10)
        ldy     #IO_GPIO_OUT_1
        lda     (io_ptr),y              ; Read Group 1 output ($18)
        eor     E
        and     tmp_h
        eor     (io_ptr),y
        sta     (io_ptr),y              ; Write updated Group 1 output ($18)
        rts

; ===========================================================================
; PORTRESET port [, pulse_len [, polarity]]
; Triggers a hardware reset pulse on the specified I/O port.
; ===========================================================================
exec_portreset:
        jsr     eval_byte_arg           ; Evaluate port (0..15)
        pha                             ; Save port
        mva     #50, tmp_l              ; Default pulse_len = 50
        mva     #$04, tmp_h             ; Default CTRL = $04 (auto-pulse, active-low)
        jsr     peek_byte               ; Optional pulse_len argument present?
        beq     @apply
        jsr     eval_next_byte_arg      ; Skip comma, evaluate pulse_len (0..255)
        sta     tmp_l
        jsr     peek_byte               ; Optional polarity argument present?
        beq     @apply
        jsr     eval_next_byte_arg      ; Skip comma, evaluate polarity (0..1)
        cmp     #2                      ; Verify polarity is 0 or 1
        bcs     port_out_of_range
        asl     A                       ; Shift polarity into bit 1
        ora     #$04                    ; Combine with auto-pulse trigger (bit 2)
        sta     tmp_h
@apply:
        pla                             ; Restore port
        ldx     #CAP_RESET
        jsr     check_io_port           ; Validate port and set up io_ptr
        ldy     #IO_RESET_PULSE_LEN
        lda     tmp_l
        sta     (io_ptr),y              ; Write pulse length ($71)
        dey                             ; Advance to IO_RESET_CTRL ($70)
        lda     tmp_h
        sta     (io_ptr),y              ; Trigger reset pulse ($70)
        rts

port_out_of_range:
        jmp     raise_out_of_range

; ===========================================================================
; PORTPWM port [, pin, period, duty [, prescaler [, invert]]]
; Configures and enables (or disables) the 16-bit PWM generator on a port.
; ===========================================================================
exec_portpwm:
        jsr     eval_byte_arg           ; Evaluate port (0..15)
        pha                             ; Save port
        stz     tmp_h                   ; Default CTRL = 0 (disabled)
        jsr     peek_byte               ; Check if only port was given
        beq     @apply_ctrl             ; 1 arg: disable PWM on port
        jsr     eval_next_byte_arg      ; Skip comma, evaluate pin (0..15)
        cmp     #16                     ; Verify pin is in range 0..15
        bcs     port_out_of_range
        asl     A                       ; Shift pin into bits 7:4
        asl     A
        asl     A
        asl     A
        ora     #$01                    ; Set bit 0 (pwm_en = 1)
        sta     tmp_h                   ; Save CTRL byte
        jsr     eval_next_int_arg       ; Skip comma, evaluate 16-bit period
        stax    arg2                    ; Save period in arg2/arg3
        jsr     eval_next_int_arg       ; Skip comma, evaluate 16-bit duty
        stax    DE                      ; Save duty in DE
        stz     tmp_l                   ; Default prescaler = 0
        jsr     peek_byte               ; Optional prescaler argument present?
        beq     @apply_all
        jsr     eval_next_byte_arg      ; Skip comma, evaluate prescaler (0..255)
        sta     tmp_l
        jsr     peek_byte               ; Optional invert argument present?
        beq     @apply_all
        jsr     eval_next_byte_arg      ; Skip comma, evaluate invert (0..1)
        cmp     #2                      ; Verify invert is 0 or 1
        bcs     port_out_of_range
        asl     A                       ; Shift invert into bit 1
        ora     tmp_h
        sta     tmp_h
@apply_all:
        pla                             ; Restore port
        ldx     #CAP_PWM
        jsr     check_io_port           ; Validate port and set up io_ptr
        ldy     #IO_PWM_PRESCALER
        lda     tmp_l
        sta     (io_ptr),y              ; Write prescaler ($51)
        iny
        lda     arg2
        sta     (io_ptr),y              ; Write period low ($52)
        iny
        lda     arg3
        sta     (io_ptr),y              ; Write period high ($53)
        iny
        lda     D
        sta     (io_ptr),y              ; Write duty low ($54)
        iny
        lda     E
        sta     (io_ptr),y              ; Write duty high ($55)
        lda     arg2                    ; If period == 0 and duty == 0, disable PWM
        ora     arg3
        ora     D
        ora     E
        bne     @write_ctrl
        stz     tmp_h
        bra     @write_ctrl

@apply_ctrl:
        pla                             ; Restore port
        ldx     #CAP_PWM
        jsr     check_io_port           ; Validate port and set up io_ptr
@write_ctrl:
        ldy     #IO_PWM_CTRL
        lda     tmp_h
        sta     (io_ptr),y              ; Write PWM control register ($50)
        rts

; ===========================================================================
; PORT(port)
; Returns the 16-bit GPIO input state for the specified I/O port.
; PROLOG_POP_INT pops port into AX.
; ===========================================================================
fun_port:
        jsr     require_byte_ax         ; Verify port high byte is 0
        ldx     #CAP_GPIO
        jsr     check_io_port           ; Validate port and set up io_ptr
        ldy     #IO_GPIO_IN_1
        lda     (io_ptr),y              ; Read Group 1 input ($19)
        tax                             ; High byte in X
        ldy     #IO_GPIO_IN_0
        lda     (io_ptr),y              ; Read Group 0 input ($11) in A
        rts

; ===========================================================================
; PORTADC(port)
; Enables the ADC slice and returns the 12-bit analog sample (0..4095).
; PROLOG_POP_INT pops port into AX.
; ===========================================================================
fun_portadc:
        jsr     require_byte_ax         ; Verify port high byte is 0
        ldx     #CAP_ANALOG
        jsr     check_io_port           ; Validate port and set up io_ptr
        ldy     #IO_ADC_CTRL
        lda     #1
        sta     (io_ptr),y              ; Ensure ADC is enabled ($60)
        ldy     #IO_ADC_DATA_LO
        lda     (io_ptr),y              ; Read low byte ($62) and latch high nibble
        pha                             ; Save low byte
        iny                             ; Advance to IO_ADC_DATA_HI ($63)
        lda     (io_ptr),y              ; Read latched high nibble
        tax                             ; High byte in X
        pla                             ; Low byte in A
        rts

