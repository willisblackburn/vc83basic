; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

.import __MAIN_START__, __MAIN_SIZE__
.import __CODE_LOAD__, __CODE_RUN__
.import __PARSER_LOAD__, __PARSER_RUN__, __PARSER_SIZE__

.segment "ONCE"

SYSTEM_ROM_START = $F800
SYSTEM_ROM_SIZE = $800

system_rom: .res SYSTEM_ROM_SIZE

; Copies the BASIC code from wherever it was loaded in RAM into the Language Card RAM.
; Also copies the system ROM into the LC RAM it continues to appear at the same addresses.
; Any subroutines used by this initialization function have to be here in this module, because the rest of the
; program has not yet been copied to the address from which it was intended to run.

initialize_target_apple2_lc:
        mvax    #SYSTEM_ROM_START, src_ptr  ; Move system ROM into RAM
        mvax    #system_rom, dst_ptr
        ldax    #SYSTEM_ROM_SIZE
        jsr     copy_lc
        lda     LCRAM                   ; Read LCRAM twice write-enable RAM
        lda     LCRAM
        lda     #$A5                    ; Write and verify to check if Langauge Card exists
        sta     $E000
        cmp     $E000
        bne     no_lc
        lda     #$5A                    ; Check different value, in case $E000 just happened to be $A5
        sta     $E000
        cmp     $E000
        bne     no_lc
        mvax    #system_rom, src_ptr        ; Copy system ROM into LC
        mvax    #SYSTEM_ROM_START, dst_ptr
        ldax    #SYSTEM_ROM_SIZE
        jsr     copy_lc
        mvax    #__CODE_LOAD__, src_ptr     ; Copy BASIC code into LC
        mvax    #__CODE_RUN__, dst_ptr
        ldax    #(__PARSER_LOAD__ + __PARSER_SIZE__ - __CODE_LOAD__)
        jsr     copy_lc
        lda     LCRAMWP                 ; Write-protect LC RAM
        jmp     initialize_target_apple2

no_lc_message: .byte "NO LANGUAGE CARD FOUND!"
no_lc_message_length = * - no_lc_message

no_lc:
        jsr     CROUT
        ldy     #0
@next:
        lda     no_lc_message,y
        ora     #$80
        jsr     COUT
        iny
        cpy     #no_lc_message_length
        bne     @next
@done:
        jsr     CROUT
        jmp     DOSWARM                 ; Bail

; We need our own copy function because the one in util.s is not available until after the copy
; is complete.

copy_lc:
        stax    size
        lda     #0                      ; Low byte of #256
        sec
        sbc     size                    ; Subtract size from 256; this is initial Y value for short block
        tay                             ; Into Y
        beq     @next_byte              ; Even number of blocks; skip all the short block stuff
        clc                             ; Add size % 256 to source_ptr
        lda     src_ptr
        adc     size
        sta     src_ptr
        bcs     @src_has_carry          ; Need to add 1 to src_ptr high byte; can just skip decrement instead
        dec     src_ptr+1
@src_has_carry:
        clc                             ; Add size % 256 to dst_ptr
        lda     dst_ptr
        adc     size
        sta     dst_ptr
        bcs     @dst_has_carry
        dec     dst_ptr+1
@dst_has_carry:
        inx                             ; Add 1 to number of blocks to account for short block

; Once we get here, X is >0, and either:
; There are X 256-byte blocks to copy, and Y is 0.
; There are X-1 256-byte blocks to copy, plus one short block, and Y is (256 - size of short block).

@next_byte: 
        lda     (src_ptr),y             ; Copy one byte
        sta     (dst_ptr),y                
        iny                             ; Next byte
        bne     @next_byte              ; More to move
        inc     src_ptr+1               ; Add 256
        inc     dst_ptr+1               ; to both src_ptr and dst_ptr
        dex                             ; Decrement number of blocks
        bne     @next_byte              ; More to move

@done:
        rts

.code
