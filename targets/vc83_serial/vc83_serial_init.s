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
        bcc     :+
        jmp     @init_fail
:

        lda     #$20
        sta     BANK_SELECT_A           ; Window A ($A000-$AFFF) -> Tile RAM ($20000-$20FFF)

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
        bne     :+
        inc     dst_ptr+1
:       lda     dst_ptr+1
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
        bcc     :+
        jmp     @init_fail
:

        lda     #$28
        sta     BANK_SELECT_A           ; Window A ($A000-$AFFF) -> Palette RAM ($28000-$28FFF)

        lda     #<$A000
        sta     dst_ptr
        lda     #>$A000
        sta     dst_ptr+1

@load_palette:
        lda     #0
        jsr     API_GET
        bcs     @palette_done
        ldy     #0
        sta     (dst_ptr), y
        inc     dst_ptr
        bne     :+
        inc     dst_ptr+1
:       lda     dst_ptr+1
        cmp     #>$A200                 ; 512 bytes -> $A000 to $A1FF
        bcc     @load_palette

@palette_done:
        lda     #0
        jsr     API_CLOSE

        ; Duplicate Palette 0 to Palette 1 ($A200), Palette 2 ($A400), Palette 3 ($A600)
        ldx     #0
@dup_pal:
        lda     $A000, x
        sta     $A200, x
        sta     $A400, x
        sta     $A600, x
        lda     $A100, x
        sta     $A300, x
        sta     $A500, x
        sta     $A700, x
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
        bcc     :+
        jmp     @init_fail
:

        ; -------------------------------------------------------------------
        ; 4. Open console C: on channel 0 (mode $32 = Layer 3, Read/Write)
        ; -------------------------------------------------------------------
        lda     #$32                    ; Mode $32: Layer 3, Read/Write
        sta     arg1
        lda     #<console_filename
        sta     arg2
        lda     #>console_filename
        sta     arg3
        lda     #console_filename_len
        sta     arg4
        lda     #0                      ; Channel 0
        jsr     API_OPEN
        bcc     :+
        jmp     @init_fail
:

        ; Set channel = 0
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
