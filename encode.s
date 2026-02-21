; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

; Functions in this module are only used when parsing program lines and are optimzed for space over speed.
; All functions write to the output buffer at index line_pos and update line_pos.
; All functions return carry clear if ok or carry set if out of space.
; All functions clobber X, so save it if you need it.

; Encodes zero.

encode_zero:
        lda     #0

; Fall through

; Encodes a single byte.
; A = the byte to encode
; Y SAFE, BC SAFE, DE SAFE

encode_byte:
        ldx     line_pos
        sta     line_buffer,x
        inc     line_pos
        rts
