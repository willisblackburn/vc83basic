; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

.segment "BUFFERS"

buffer:         .res 256
line_buffer:    .res 256

.segment "ONCE"     

charset_filename:
        .byte   "B:CHARSET.DAT"
charset_filename_len = * - charset_filename

palette_filename:
        .byte   "B:PALETTE.DAT"
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
        ; 1. Load standard font from B:CHARSET.DAT into Tile RAM Bank 0
        ; -------------------------------------------------------------------
        mvax    #charset_filename, path_ptr
        mva     #charset_filename_len, path_len
        stz     arg1
        stz     arg2
        stz     arg3
        stz     io_ptr
        stz     io_ptr+1
        mva     #$A0, io_seg            ; Tile RAM Bank 0 ($A0000-$A07FF)
        mvax    #2048, io_len
        jsr     API_LOAD
        bcc     @open_font_ok
        jmp     @init_fail
@open_font_ok:

        ; -------------------------------------------------------------------
        ; 2. Load palette from B:PALETTE.DAT into Palette RAM
        ; -------------------------------------------------------------------
        mvax    #palette_filename, path_ptr
        mva     #palette_filename_len, path_len
        stz     arg1
        stz     arg2
        stz     arg3
        mvax    #$0800, io_ptr
        mva     #$B0, io_seg            ; Palette 0 RAM ($B0800-$B09FF)
        mvax    #512, io_len
        jsr     API_LOAD
        bcc     @open_palette_ok
        jmp     @init_fail
@open_palette_ok:

        mva     #$B0, BANK_SELECT_A     ; Window A ($A000-$AFFF) -> Palette RAM ($B0800-$B0FFF)

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
        stz     BANK_SELECT_A

        ; -------------------------------------------------------------------
        ; 3. Initialize text graphics mode (80x25 text on Layer 2, GRMODE 0)
        ; -------------------------------------------------------------------
        lda     #0
        ldx     #0
        jsr     exec_grmode
        bcc     @grmode_ok
        jmp     @init_fail
@grmode_ok:

        ; Set channel = 0 (default channel)
        stz     channel
        stz     default_channel

        ; -------------------------------------------------------------------
        ; 5. Display startup banner to screen
        ; -------------------------------------------------------------------
        jmp     display_startup_banner

.bss

.align 256
stack:          .res PRIMARY_STACK_SIZE
op_stack:       .res OP_STACK_SIZE

.code
