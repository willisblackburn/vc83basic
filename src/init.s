; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

.segment "ONCE"

; We only need the start message at startup, so we put it in the ONCE segment so it can later be overwritten by
; program data. Free memory is a constant; subtract 5 in order to account for null line (3 bytes) and end byte
; for variable and array name tables.

startup_message:  .byte "VC83 BASIC "
.if .defined(__APPLE2__)    ; If Apple II then remap version number to uppercase
                .pushcharmap
                .repeat 26, i
                .charmap $61 + i, $41 + i
                .endrep
.endif
.include "version.inc"
.if .defined(__APPLE2__)
                .popcharmap
.endif
                .byte " <> "
startup_message_length = * - startup_message

free_message:   .byte " BYTES FREE"
free_message_length = * - free_message

fp_64k:         .byte $00, $00, $00, $00, 144

display_startup_banner:
        ldax    #startup_message
        ldy     #startup_message_length
        jsr     write
        ldax    #((__MAIN_START__ + __MAIN_SIZE__) - (__BSS_RUN__ + __BSS_SIZE__) - 5)
        jsr     int_to_fp               ; Load into FP0
        lda     FP0s                    ; Check if it was negative
        bpl     @positive
        lday    #fp_64k                 ; Add 64K to get the correct number
        jsr     fadd
@positive:
        jsr     print_number
        ldax    #free_message
        ldy     #free_message_length
        jsr     write
        jmp     newline

.code
