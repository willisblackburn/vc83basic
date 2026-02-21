; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

; Gets the value for an expression and returns it in AX.

evaluate_expression:
        ldy     line_pos
        lda     (line_ptr),y            ; Peek at the next byte
        cmp     #'A'                    ; Does it look like a name?
        bcs     @variable               ; Yep
        jsr     decode_number           ; Decode a number instead
        clc
        rts

@variable:
        jsr     decode_name
        jsr     find_or_add_variable
        bcs     @error
        ldy     #1                      ; Start with high byte of value
        lda     (name_ptr),y
        tax
        dey
        lda     (name_ptr),y
        clc                             ; Success
@error:
        rts
