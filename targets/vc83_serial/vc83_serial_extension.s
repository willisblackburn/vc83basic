; SPDX-FileCopyrightText: 2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

.segment "BSS"
dir_record:     .res 15
dir_name        = dir_record
dir_size        = dir_record + 11

tmp_l:          .res 1
tmp_h:          .res 1
grmode_val:     .res 1
grmode_base:    .res 1
grmode_fmt:     .res 1
grmode_frm:     .res 1
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
        bcs     ext_io_err
        rts

; XIO [#channel] {command}[,{arg1}[,{arg2}]]
exec_xio:
        jsr     eval_byte_arg           ; Evaluate command (0..255) -> A
        pha                             ; Save command on stack
        stz     arg2                    ; Default arg1 = 0
        stz     arg3
        stz     arg4                    ; Default arg2 = 0
        stz     arg5
        jsr     peek_byte
        beq     @do_xio
        jsr     eval_next_int_arg       ; Skip comma, evaluate arg1 -> AX
        pha                             ; Save arg1 low
        phx                             ; Save arg1 high
        jsr     peek_byte
        beq     @pop_arg1
        jsr     eval_next_int_arg       ; Skip comma, evaluate arg2 -> AX
        sta     arg4
        stx     arg5
@pop_arg1:
        plx
        stx     arg3
        pla
        sta     arg2
@do_xio:
        pla                             ; Restore command into arg1
        sta     arg1
        lda     channel
        and     #$07
        jsr     API_XIO
        bcs     ext_io_err
        rts

ext_io_err:
        raise   ERR_IO_ERROR

; DIR [{path}]
exec_dir:
        stz     path_len                ; Default to empty path ("", assumes "A:")
        jsr     peek_byte
        beq     @check_channel          ; No argument: use empty path
        jsr     evaluate_expression
        jsr     push_pending
        jsr     pop_string_s0           ; Pop path into S0, length in A
        sta     path_len
        mvax    S0, path_ptr
@check_channel:
        ; Check if Channel 7 is open by inspecting IOCB 7 ($02E0)
        lda     $02E0                   ; IOCB 7 device byte
        bpl     @channel_available
        jmp     raise_io_error          ; Already open: fail without closing channel 7
@channel_available:
        lda     #OPEN_DIRECTORY
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
        bcs     ext_io_err
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
; Configures VCGA graphics layers, clears layer VRAM, reloads default palettes,
; and manages the console lifecycle.
;
; Mode argument:
;   Bits 6:0: Preset mode (0..27)
;     0..3:   Console modes (Layer 2 full screen, Layer 3 disabled)
;             0: 80x25 text (tall, 640x400) - Default console mode
;             1: 53x30 text (2X, 848x480)
;             2: 106x30 text (tall, 848x480)
;             3: 106x60 text (1X, 848x480)
;     4..15:  Bitmap graphics modes (Layer 3 full screen, Palette 3)
;             4:  160x100x256 (4X, 8bpp, 640x400)
;             5:  320x200x256 (2X, 8bpp, 640x400)
;             6:  640x200x16  (tall, 4bpp, 640x400)
;             7:  640x400x4   (1X, 2bpp, 640x400)
;             8:  176x92x256  (4X, 8bpp, 704x368)
;             9:  352x184x256 (2X, 8bpp, 704x368)
;             10: 704x184x16  (tall, 4bpp, 704x368)
;             11: 704x368x4   (1X, 2bpp, 704x368)
;             12: 212x120x256 (4X, 8bpp, 848x480)
;             13: 424x240x16  (2X, 4bpp, 848x480)
;             14: 848x240x4   (tall, 2bpp, 848x480)
;             15: 848x480x2   (1X, 1bpp, 848x480)
;     16..27: Tilemap modes (Layer 3 full screen, Palette 3, Tile slot 0)
;             16: 40x25 tilemap 4bpp (2X, 4bpp, 640x400)
;             17: 40x25 tilemap 8bpp (2X, 8bpp, 640x400)
;             18: 80x50 tilemap 4bpp (1X, 4bpp, 640x400)
;             19: 80x50 tilemap 8bpp (1X, 8bpp, 640x400)
;             20: 44x23 tilemap 4bpp (2X, 4bpp, 704x368)
;             21: 44x23 tilemap 8bpp (2X, 8bpp, 704x368)
;             22: 88x46 tilemap 4bpp (1X, 4bpp, 704x368)
;             23: 88x46 tilemap 8bpp (1X, 8bpp, 704x368)
;             24: 53x30 tilemap 4bpp (2X, 4bpp, 848x480)
;             25: 53x30 tilemap 8bpp (2X, 8bpp, 848x480)
;             26: 106x60 tilemap 4bpp (1X, 4bpp, 848x480)
;             27: 106x60 tilemap 8bpp (1X, 8bpp, 848x480)
;   Bit 7 (+128):
;     In graphics/tilemap modes (4..27), the 4-line transparent console window
;     at the bottom of the active frame on Layer 2 is shown by default (bit 7 = 0).
;     Setting bit 7 (+128) suppresses/hides the console window.
; ===========================================================================

mode_table_format:
        ; Packed as (frame << 5) | format:
        ;   frame: $00 = Standard (640x400), $20 = Wide (704x368), $40 = Full (848x480)
        ;   format: bit 4 = tilemap, bits 3:2 = scale (1X, 2X, 4X, tall), bits 1:0 = bpp
        ; Console modes (0..3)
        .byte   $1F                     ; 0:  80x25 text (tall, 1bpp, 640x400)
        .byte   $40 | $17               ; 1:  53x30 text (2X, 1bpp, 848x480)
        .byte   $40 | $1F               ; 2:  106x30 text (tall, 1bpp, 848x480)
        .byte   $40 | $13               ; 3:  106x60 text (1X, 1bpp, 848x480)

        ; Bitmap graphics modes (4..15)
        .byte   $08                     ; 4:  160x100x256 (4X, 8bpp, 640x400)
        .byte   $04                     ; 5:  320x200x256 (2X, 8bpp, 640x400)
        .byte   $0D                     ; 6:  640x200x16  (tall, 4bpp, 640x400)
        .byte   $02                     ; 7:  640x400x4   (1X, 2bpp, 640x400)
        .byte   $20 | $08               ; 8:  176x92x256  (4X, 8bpp, 704x368)
        .byte   $20 | $04               ; 9:  352x184x256 (2X, 8bpp, 704x368)
        .byte   $20 | $0D               ; 10: 704x184x16  (tall, 4bpp, 704x368)
        .byte   $20 | $02               ; 11: 704x368x4   (1X, 2bpp, 704x368)
        .byte   $40 | $08               ; 12: 212x120x256 (4X, 8bpp, 848x480)
        .byte   $40 | $05               ; 13: 424x240x16  (2X, 4bpp, 848x480)
        .byte   $40 | $0E               ; 14: 848x240x4   (tall, 2bpp, 848x480)
        .byte   $40 | $03               ; 15: 848x480x2   (1X, 1bpp, 848x480)

        ; Tilemap modes (16..27)
        .byte   $15                     ; 16: 40x25 tilemap 4bpp (2X, 4bpp, 640x400)
        .byte   $14                     ; 17: 40x25 tilemap 8bpp (2X, 8bpp, 640x400)
        .byte   $11                     ; 18: 80x50 tilemap 4bpp (1X, 4bpp, 640x400)
        .byte   $10                     ; 19: 80x50 tilemap 8bpp (1X, 8bpp, 640x400)
        .byte   $20 | $15               ; 20: 44x23 tilemap 4bpp (2X, 4bpp, 704x368)
        .byte   $20 | $14               ; 21: 44x23 tilemap 8bpp (2X, 8bpp, 704x368)
        .byte   $20 | $11               ; 22: 88x46 tilemap 4bpp (1X, 4bpp, 704x368)
        .byte   $20 | $10               ; 23: 88x46 tilemap 8bpp (1X, 8bpp, 704x368)
        .byte   $40 | $15               ; 24: 53x30 tilemap 4bpp (2X, 4bpp, 848x480)
        .byte   $40 | $14               ; 25: 53x30 tilemap 8bpp (2X, 8bpp, 848x480)
        .byte   $40 | $11               ; 26: 106x60 tilemap 4bpp (1X, 4bpp, 848x480)
        .byte   $40 | $10               ; 27: 106x60 tilemap 8bpp (1X, 8bpp, 848x480)

frame_x:                .byte   104, 72, 0
frame_y0:               .byte   40, 56, 0
frame_width_low:        .byte   <640, <704, <848
frame_width_high:       .byte   >640, >704, >848
frame_height0_low:      .byte   <400, <368, <480
frame_height0_high:     .byte   >400, >368, >480
frame_con_y_low:        .byte   <376, <360, <416
frame_con_stride:       .byte   80, 88, 112

scale_width_bits:       .byte   0, 1, 2, 0
scale_height_bits:      .byte   0, 1, 2, 1
scale_stretch:          .byte   $00, $05, $0A, $04

grmode_palette_name:    .byte   "B:PALETTE.DAT"
grmode_palette_name_len = 13

grmode_charset_name:    .byte   "B:CHARSET.DAT"
grmode_charset_name_len = 13

grmode_console_name:    .byte   "C:"
grmode_console_name_len = 2

grmode_host_name:       .byte   "H:"
grmode_host_name_len    = 2

grmode_screen_name:     .byte   "S3:"
grmode_screen_name_len  = 3

exec_grmode:
        cpx     #0                      ; Validate mode fits in 0..255
        beq     @arg_ok
@arg_err:
        jmp     raise_out_of_range

@arg_ok:
        sta     grmode_val              ; Save full mode byte (including bit 7)
        and     #$7F                    ; Strip console suppress flag (bit 7)
        sta     grmode_base
        cmp     #28                     ; Validate preset index 0..27
        bcs     @arg_err
        tax
        lda     mode_table_format,x     ; Load packed (frame << 5) | format
        pha
        and     #$1F                    ; Extract 5-bit format
        sta     grmode_fmt
        pla
        lsr     A                       ; Shift frame (bits 6:5) into bits 1:0
        lsr     A
        lsr     A
        lsr     A
        lsr     A
        sta     grmode_frm

        ; Close graphics channel 6
        lda     #6
        jsr     API_CLOSE

        ; Disable layers 0 and 1, set background to Palette 2 Color 0, disable all 32 sprites
        mva     #$B0, BANK_SELECT_D
        stz     $D00C                   ; Layer 0 mode = 0 (disabled)
        stz     $D02C                   ; Layer 1 mode = 0 (disabled)
        mva     #2, $D080               ; Background palette = 2
        stz     $D081                   ; Background color = 0
        ldx     #0
        clc
@clear_sprites:
        stz     $D106,x                 ; Disable sprite flags/stretch
        txa
        adc     #8
        tax
        bne     @clear_sprites

        ; Reload Palette 2 ($B0C00) and console charset in Tile Slot 7 ($A3800)
        lda     #$0C
        jsr     load_palette
        bcs     @io_err
        jsr     load_font_slot7
        bcs     @io_err

        ; Dispatch console modes (0..3) vs graphics/tilemap modes (4..27)
        lda     grmode_base
        cmp     #4
        bcs     @setup_graphics

        ; -------------------------------------------------------------
        ; Pure Console Mode (0..3)
        ; -------------------------------------------------------------
        mva     #$B0, BANK_SELECT_D
        stz     $D06C                   ; Disable Layer 3

        ; Configure Layer 2 full-frame: tile set 7, palette 2, 1bpp, opaque ($7B)
        lda     #$7B
        ldx     #$40
        jsr     setup_full_layer

        ; If channel 0 is open to other device (e.g. H:), leave it alone
        jsr     is_channel_0_other      ; Carry set if open to non-console device
        bcs     @text_done

        jsr     @open_console_or_host
        bcs     @io_err
@text_done:
        jmp     @exit

@io_err:
        mva     #$E0, BANK_SELECT_D
        jmp     raise_io_error

        ; -------------------------------------------------------------
        ; Graphics / Tilemap Mode (4..27)
        ; -------------------------------------------------------------
@setup_graphics:
        ; Configure Layer 3 full-frame: tile set 0, palette 3, bpp, opaque ($0C | bpp)
        lda     grmode_fmt
        and     #$03
        ora     #$0C
        ldx     #$60
        jsr     setup_full_layer

        ; Reload Palette 3 ($B0E00)
        lda     #$0E
        jsr     load_palette
        bcs     @io_err

        ; Open channel 6 to graphics layer S3:
        mva     #OPEN_READ_WRITE, arg1
        mvax    #grmode_screen_name, path_ptr
        mva     #grmode_screen_name_len, path_len
        lda     #6
        jsr     API_OPEN
        bcs     @io_err

        ; If channel 0 is open to other device, leave channel 0 alone and disable Layer 2
        jsr     is_channel_0_other      ; Carry set if open to non-console device
        bcc     @setup_l2_console

        mva     #$B0, BANK_SELECT_D
        stz     $D04C                   ; Disable Layer 2
        bra     @exit

@setup_l2_console:
        ; Configure Layer 2 as 4-line transparent console window at bottom of active frame
        mva     #$B0, BANK_SELECT_D
        ldy     grmode_frm
        lda     frame_x,y
        sta     $D040                   ; X low
        stz     $D041                   ; X high = 0
        lda     frame_con_y_low,y
        sta     $D042                   ; Y low (376, 360, or 416)
        mva     #$01, $D043             ; Y high = $01
        lda     frame_width_low,y
        sta     $D044                   ; WIDTH low
        lda     frame_width_high,y
        sta     $D045                   ; WIDTH high
        mva     #32, $D046              ; HEIGHT low = 32 (64 screen lines / 2)
        stz     $D047                   ; HEIGHT high = 0
        stz     $D048                   ; BASE_ADDRESS low = $00
        mva     #$FE, $D049             ; BASE_ADDRESS high = $FE ($FE00)
        lda     frame_con_stride,y
        sta     $D04A                   ; STRIDE low (80, 88, or 112)
        stz     $D04B                   ; STRIDE high = 0
        mva     #3, $D04C               ; MODE = 3 (tilemap)
        mva     #$FB, $D04D             ; ATTRIBUTES = transparent, tile set 7, palette 2, 1bpp
        mva     #$04, $D04E             ; STRETCH = $04 (tall: 1X width, 2X height)
        ldx     #4
@zero_l2_tail:
        stz     $D04F,x                 ; Zero COLOR_SHIFT, HSCROLL, VSCROLL, ATTR_OFFSET
        dex
        bpl     @zero_l2_tail

        ; Re-open channel 0 to console on Layer 2 (clears $FE00 with spaces; falls back to H:)
        jsr     @open_console_or_host
        bcc     @check_suppress
        jmp     @io_err

@check_suppress:
        ; Bit 7 = 0 (default): keep console window visible; Bit 7 = 1 (+128): suppress it
        lda     grmode_val
        bpl     @exit
        jsr     @hide_l2

@exit:
        mva     #$E0, BANK_SELECT_D     ; Restore standard peripheral bank
        clc
        rts

@hide_l2:
        mva     #$B0, BANK_SELECT_D     ; Select VCGA register bank
        stz     $D04C                   ; Layer 2 mode = 0 (hidden)
        stz     $D1FE                   ; Disable Sprite 31 cursor
        rts

@open_console_or_host:
        lda     #0                      ; Close existing channel 0
        jsr     API_CLOSE

        mva     #(2 << 5) | OPEN_READ_WRITE, arg1
        mvax    #grmode_console_name, path_ptr
        mva     #grmode_console_name_len, path_len
        lda     #0
        jsr     API_OPEN
        bcc     @open_done              ; Success: C: is open on channel 0

        ; C: unavailable (no keyboard): hide Layer 2 and open H: on channel 0
        jsr     @hide_l2
        mva     #OPEN_READ_WRITE, arg1
        mvax    #grmode_host_name, path_ptr
        mva     #grmode_host_name_len, path_len
        lda     #0
        jmp     API_OPEN

@open_done:
        rts

; Configures a full-frame VCGA layer at BASE = $0000 and clears its VRAM.
; A = layer attributes, X = layer register offset ($40 or $60).
setup_full_layer:
        stx     tmp_l                   ; Save layer register offset ($40 or $60)
        sta     tmp_h                   ; Save layer attributes

        ; Extract scale (bits 3:2) into X
        lda     grmode_fmt
        lsr     A
        lsr     A
        and     #3
        tax                             ; X = scale (0..3)

        ; Load unscaled frame width into BC and height into DE
        ldy     grmode_frm
        lda     frame_width_low,y
        sta     B
        lda     frame_width_high,y
        sta     C
        lda     frame_height0_low,y
        sta     D
        lda     frame_height0_high,y
        sta     E

        ; Scale logical width and height by stretch factor
        phx                             ; Save scale
        ldy     scale_width_bits,x
        ldx     #B
        jsr     shr_zp_word             ; BC = width >> scale_width_bits[scale]
        plx
        ldy     scale_height_bits,x
        ldx     #D
        jsr     shr_zp_word             ; DE = height >> scale_height_bits[scale]

        ; Write X, Y, WIDTH, HEIGHT, and BASE_ADDRESS ($0000) to layer registers
        mva     #$B0, BANK_SELECT_D
        ldx     tmp_l
        ldy     grmode_frm
        lda     frame_x,y
        sta     $D000,x                 ; X low
        stz     $D001,x                 ; X high = 0
        lda     frame_y0,y
        sta     $D002,x                 ; Y low
        stz     $D003,x                 ; Y high = 0
        lda     B
        sta     $D004,x                 ; WIDTH low
        lda     C
        sta     $D005,x                 ; WIDTH high
        lda     D
        sta     $D006,x                 ; HEIGHT low
        lda     E
        sta     $D007,x                 ; HEIGHT high
        stz     $D008,x                 ; BASE_ADDRESS low = 0
        stz     $D009,x                 ; BASE_ADDRESS high = 0

        ; Compute VRAM row count (DE) and 8-byte aligned row stride (BC)
        lda     grmode_fmt
        and     #3
        tay                             ; Y = bpp (0..3) for bitmap stride shift
        lda     grmode_fmt
        and     #$10                    ; Bit 4 = kind (0 = bitmap, $10 = tilemap)
        beq     @round_stride           ; Bitmap: rows = height, shift = bpp
        ldx     #D
        ldy     #3
        jsr     shr_zp_word             ; Tilemap: rows = height >> 3
        ldy     #3                      ; Tilemap: 1 byte per 8-pixel tile column
@round_stride:
        lda     B                       ; Compute (((width - 1) >> Y) + 8) & $FFF8
        bne     @dec_b                  ; Check borrow from high byte
        dec     C
@dec_b:
        dec     B
        ldx     #B
        jsr     shr_zp_word
        lda     B
        clc
        adc     #8
        and     #$F8
        sta     B
        bcc     @stride_done
        inc     C
@stride_done:

        ; Write STRIDE, MODE, ATTRIBUTES, STRETCH, and zero remaining layer registers
        ldx     tmp_l
        lda     B
        sta     $D00A,x                 ; STRIDE low
        lda     C
        sta     $D00B,x                 ; STRIDE high
        lda     grmode_fmt              ; Mode = 1 (bitmap) or 3 (tilemap)
        lsr     A
        lsr     A
        lsr     A
        and     #2
        ora     #1
        sta     $D00C,x                 ; MODE
        lda     tmp_h
        sta     $D00D,x                 ; ATTRIBUTES
        lda     grmode_fmt
        lsr     A
        lsr     A
        and     #3
        tay
        lda     scale_stretch,y
        sta     $D00E,x                 ; STRETCH
        stz     $D00F,x                 ; COLOR_SHIFT = 0
        stz     $D010,x                 ; HSCROLL = 0
        stz     $D011,x                 ; VSCROLL = 0
        stz     $D012,x                 ; ATTR_OFFSET low = 0
        stz     $D013,x                 ; ATTR_OFFSET high = 0

        ; Zero-fill stride * rows bytes of VRAM starting at $80:0000
        stz     MUL_C
        stz     MUL_C+1
        stz     MUL_C+2
        mvax    B, MUL_A
        mvax    D, MUL_B
        stz     MODE                    ; MODE_8BPP, DST_STEP = 1
        stz     DST_ADDR
        stz     DST_ADDR+1
        mva     #$80, DST_ADDR+2
        ldx     MUL_RESULT              ; Low byte of VRAM byte count
        ldy     MUL_RESULT+1            ; High byte of VRAM byte count
        iny
        txa
        beq     @clear_chk_hi
@clear_loop:
        stz     DST_DATA_INC            ; Clear VRAM byte and advance DST_ADDR
        dex
        bne     @clear_loop
@clear_chk_hi:
        dey
        bne     @clear_loop
        rts

; Shifts 16-bit zero-page word at (0,x) right by Y bits.
shr_zp_word:
        dey
        bmi     @done
        lsr     1,x
        ror     0,x
        bra     shr_zp_word

@done:
        rts

; Loads 512-byte default palette from B:PALETTE.DAT into $B0:(A << 8).
load_palette:
        sta     io_ptr+1
        stz     io_ptr
        mvax    #grmode_palette_name, path_ptr
        mva     #grmode_palette_name_len, path_len
        mva     #$B0, io_seg            ; Palette RAM ($B0800-$B0FFF)
        mvax    #512, io_len
        bra     load_from_offset_0

load_font_slot7:
        mvax    #grmode_charset_name, path_ptr
        mva     #grmode_charset_name_len, path_len
        mvax    #$3800, io_ptr
        mva     #$A0, io_seg            ; Tile RAM Bank 7 ($A3800-$A3FFF)
        mvax    #2048, io_len
load_from_offset_0:
        stz     arg1
        stz     arg2
        stz     arg3
        jmp     API_LOAD


; ===========================================================================
; COLOR [#channel] n
; MOVE [#channel] x, y
; PLOT [#channel] x, y
; DRAWTO [#channel] x, y
; FILLTO [#channel] x, y
; LOCATE([#channel] x, y)
; Graphics primitives dispatched via XIO on S: (default channel 6).
; ===========================================================================
fun_locate:
        lda     channel                 ; Save outer statement's channel
        pha
        ldx     #6                      ; Default to channel 6
        jsr     peek_byte
        sec
        sbc     #TOK_CHANNEL_0
        cmp     #8
        bcs     @got_ch
        inc     line_pos                ; Consume channel token
        ora     #$80
        tax
@got_ch:
        phx                             ; Save LOCATE's channel across arg evaluation
        jsr     evaluate_argument_list  ; Evaluate x, y onto stack
        jsr     pop_int_fp0             ; Pop Y into AX
        ply
        sty     channel                 ; Set LOCATE's channel for do_screen_xio_xy
        ldy     #XIO_LOCATE
        jsr     do_screen_xio_xy        ; Returns color/tile in AX (X=0)
        ply
        sty     channel                 ; Restore outer statement's channel
        rts

exec_color:
        sta     arg2
        lda     #XIO_COLOR
        bra     call_screen_xio

exec_move:
        ldy     #XIO_MOVE
        .byte   $2C
exec_plot:
        ldy     #XIO_PLOT
        .byte   $2C
exec_drawto:
        ldy     #XIO_DRAWTO
        .byte   $2C
exec_fillto:
        ldy     #XIO_FILLTO
do_screen_xio_xy:
        phy                             ; Save XIO command
        sta     arg4                    ; Y low
        stx     arg5                    ; Y high
        jsr     pop_int_fp0             ; Pop X into AX
        stax    arg2                    ; X low/high
        pla                             ; A = XIO command
call_screen_xio:
        sta     arg1
        lda     channel                 ; Use explicit channel if bit 7 set
        bmi     @explicit
        lda     #6                      ; Otherwise default to graphics channel 6
@explicit:
        and     #$07
        jsr     API_XIO
        bcs     @err
        rts
@err:
        jmp     raise_io_error

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

        ; Point SRC_ADDR to VCGA Frame Count [7:0] at $B0082
        stz     MODE
        mvax    #$0082, SRC_ADDR
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
        lda     #2                      ; Default clk_div = 2 (8.44 MHz)
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
        lda     #85                     ; Default clk_div = 85 (~99.3 kHz)
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
        mva     #63, tmp_l              ; Default pulse_len = 63 (~478 us)
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

eval_midi_header:
        sta     tmp_h                   ; Save status opcode ($90, $B0, or $C0)
        jsr     eval_byte_arg           ; Evaluate MIDI channel (1..16)
        dec     A                       ; Convert 1..16 to 0..15
        cmp     #16
        bcs     port_out_of_range
        ora     tmp_h
        sta     tmp_h                   ; Store full status byte ($9n, $Bn, or $Cn)
        jsr     eval_next_midi_byte     ; Evaluate first 7-bit data byte (0..127)
        sta     tmp_l
        rts

eval_next_midi_byte:
        jsr     eval_next_byte_arg      ; Skip comma and evaluate byte (0..255)
        bmi     port_out_of_range       ; MIDI data bytes must be 0..127
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

; ===========================================================================
; NOTE [#channel] mchan, note [, velocity]
; PROGRAM [#channel] mchan, program
; CONTROL [#channel] mchan, controller, value
; Sends MIDI messages to the specified channel (default channel 5).
; mchan is 1..16; note, velocity, program, controller, and value are 0..127.
; Omitting velocity in NOTE defaults to 0 (Note Off).
; ===========================================================================
exec_program:
        lda     #$C0                    ; Program Change status ($Cn)
        jsr     eval_midi_header        ; tmp_h = $Cn, tmp_l = program (0..127)
        bra     midi_send_2

exec_control:
        lda     #$B0                    ; Control Change status ($Bn)
        jsr     eval_midi_header        ; tmp_h = $Bn, tmp_l = controller (0..127)
        jsr     eval_next_midi_byte     ; Evaluate value (0..127)
        bra     midi_send_3

exec_note:
        lda     #$90                    ; Note On status ($9n)
        jsr     eval_midi_header        ; tmp_h = $9n, tmp_l = note (0..127)
        jsr     peek_byte               ; Optional velocity argument present?
        beq     midi_send_3             ; No -> A is 0 (velocity = 0, Note Off)
        jsr     eval_next_midi_byte     ; Evaluate velocity (0..127)

midi_send_3:
        pha                             ; Save 2nd data byte
        jsr     midi_send_2             ; Send status (tmp_h) and 1st data byte (tmp_l)
        pla                             ; Restore 2nd data byte
        bra     midi_put_byte

midi_send_2:
        lda     tmp_h                   ; Send status byte
        jsr     midi_put_byte
        lda     tmp_l                   ; Send 1st data byte
midi_put_byte:
        sta     arg1
        lda     channel                 ; Use explicit channel if bit 7 set
        bmi     @explicit
        lda     #5                      ; Otherwise default to MIDI channel 5
@explicit:
        and     #$07
        jsr     API_PUT
        bcs     @err
        rts
@err:
        jmp     raise_io_error


