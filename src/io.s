; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

; I/O statements and functions


; GET [#channel] {numeric_variable}

exec_get:
        jsr     get_variable
        lda     var_name_type
        bne     @type_mismatch
        jsr     getch
        ldx     #0                      ; High byte 0
        bcc     @got_byte               ; If not EOF then byte is in A
        lda     #$FF                    ; -1 in AX on EOF ($FFFF)
        dex
@got_byte:
        jsr     int_to_fp
        jmp     assign_variable

@type_mismatch:
        jmp     raise_type_mismatch

; PUT [#channel] {expression}
; PROLOG_POP_INT has already evaluated the expression and popped the byte into A!

exec_put:
        jsr     putch
        bcs     raise_io_error
        rts

raise_io_error:
        raise   ERR_IO_ERROR


; SAVE {name}
; PROLOG_POP_STRING has already evaluated the filename and loaded S0!

exec_save:
        jsr     save
        bcs     raise_io_error
        rts

; LOAD {name}
; PROLOG_POP_STRING has already evaluated the filename and loaded S0!

exec_load:
        ldy     #Line::next_line_offset
        lda     (program_ptr),y
        beq     @empty
        jmp     raise_exists            ; Program exists: user must do NEW first!
@empty:
        jsr     load
        bcs     raise_io_error
        rts
