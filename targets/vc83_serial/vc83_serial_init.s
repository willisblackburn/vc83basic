; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

.segment "BUFFERS"

buffer:         .res 256
line_buffer:    .res 256

.segment "ONCE"     

charset_filename:
        .byte   "A:CHARSET.DAT"
charset_filename_len = * - charset_filename

palette_filename:
        .byte   "A:PALETTE.DAT"
palette_filename_len = * - palette_filename

console_filename:
        .byte   "C:"
console_filename_len = * - console_filename

initialize_target:        
        ; Initialize expression stacks
        lda     #PRIMARY_STACK_SIZE
        sta     stack_pos
        lda     #OP_STACK_SIZE
        sta     op_stack_pos

        ; Set HIMEM to top of RAM
        mvax    #$A000, himem_ptr

        jmp     @start_init

@init_fail:
        jmp     @init_fail

@start_init:
        ; -------------------------------------------------------------------
        ; 1. Load standard font from A:CHARSET.DAT into Tile RAM Bank 0
        ; -------------------------------------------------------------------
        lda     #OPEN_READ
        sta     arg1
        lda     #<charset_filename
        sta     arg2
        lda     #>charset_filename
        sta     arg3
        lda     #charset_filename_len
        sta     arg4
        lda     #0                      ; Channel 0
        jsr     API_OPEN
        bcc     @open_font_ok
        jmp     @init_fail
@open_font_ok:

        lda     #$A0
        sta     BANK_SELECT_A           ; Window A ($A000-$AFFF) -> Tile RAM ($A0000-$A0FFF)

        lda     #<$A000
        sta     dst_ptr
        lda     #>$A000
        sta     dst_ptr+1

@load_font:
        lda     #0
        jsr     API_GET
        bcs     @font_done
        ldy     #0
        sta     (dst_ptr), y
        inc     dst_ptr
        bne     @no_font_ptr_carry
        inc     dst_ptr+1
@no_font_ptr_carry:
        lda     dst_ptr+1
        cmp     #>$A800                 ; 2048 bytes -> $A000 to $A7FF
        bcc     @load_font

@font_done:
        lda     #0
        jsr     API_CLOSE

        ; -------------------------------------------------------------------
        ; 2. Load palette from A:PALETTE.DAT into Palette RAM
        ; -------------------------------------------------------------------
        lda     #OPEN_READ
        sta     arg1
        lda     #<palette_filename
        sta     arg2
        lda     #>palette_filename
        sta     arg3
        lda     #palette_filename_len
        sta     arg4
        lda     #0                      ; Channel 0
        jsr     API_OPEN
        bcc     @open_palette_ok
        jmp     @init_fail
@open_palette_ok:

        lda     #$B0
        sta     BANK_SELECT_A           ; Window A ($A000-$AFFF) -> Palette RAM ($B0800-$B0FFF)

        lda     #<$A800
        sta     dst_ptr
        lda     #>$A800
        sta     dst_ptr+1

@load_palette:
        lda     #0
        jsr     API_GET
        bcs     @palette_done
        ldy     #0
        sta     (dst_ptr), y
        inc     dst_ptr
        bne     @no_pal_ptr_carry
        inc     dst_ptr+1
@no_pal_ptr_carry:
        lda     dst_ptr+1
        cmp     #>$AA00                 ; 512 bytes -> $A800 to $A9FF
        bcc     @load_palette

@palette_done:
        lda     #0
        jsr     API_CLOSE

        ; Duplicate Palette 0 to Palette 1 ($AA00), Palette 2 ($AC00), Palette 3 ($AE00)
        ldx     #0
@dup_pal:
        lda     $A800, x
        sta     $AA00, x
        sta     $AC00, x
        sta     $AE00, x
        lda     $A900, x
        sta     $AB00, x
        sta     $AD00, x
        sta     $AF00, x
        inx
        bne     @dup_pal

        ; Restore BANK_SELECT_A = 0
        lda     #0
        sta     BANK_SELECT_A

        ; -------------------------------------------------------------------
        ; 3. Initialize text graphics mode (80x25 text on Layer 3, format $1C)
        ; -------------------------------------------------------------------
        lda     #$1C
        ldx     #0
        jsr     exec_grmode
        bcc     @grmode_ok
        jmp     @init_fail
@grmode_ok:

        ; Set channel = 0 (default channel)
        lda     #0
        sta     channel

        ; -------------------------------------------------------------------
        ; 5. Display startup banner to screen
        ; -------------------------------------------------------------------
        jmp     display_startup_banner

.bss

.align 256
stack:          .res PRIMARY_STACK_SIZE
op_stack:       .res OP_STACK_SIZE

.code
