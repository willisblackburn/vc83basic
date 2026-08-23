; SPDX-FileCopyrightText: 2026 Willis Blackburn and Daniel Serpell
;
; SPDX-License-Identifier: MIT

; Buffers

.segment "BUFFERS"

buffer: .res BUFFER_SIZE
line_buffer: .res BUFFER_SIZE

; Primary stack
stack: .res PRIMARY_STACK_SIZE
; Operator stack
op_stack: .res OP_STACK_SIZE

.bss

; Align vectors to an even boundary because we JMP through them, avoiding
; the 6502 indirect JMP page-crossing defect ($xxFF).
.align  2
old_dosini:     .res 2
old_dosvec:     .res 2

.code

initialize_target:
        mvax    DOSINI, old_dosini      ; Save original DOS init vector
        mvax    DOSVEC, old_dosvec      ; Save original DOS run vector
        mvax    #dos_init_handler, DOSINI ; Hook DOS init on System Reset
        mvax    #reset_handler, DOSVEC  ; System Reset jumps to BASIC
        jsr     init_k_vector
        jmp     display_startup_banner

dos_init_handler:
        jsr     call_old_dosini         ; Initialize DOS buffers / FMS
        mvax    #dos_init_handler, DOSINI ; In case DOS reset DOSINI
        mvax    #reset_handler, DOSVEC  ; Reassert BASIC run vector
        rts                             ; Return to OS so it can open E:

call_old_dosini:
        jmp     (old_dosini)

reset_handler:
        jsr     init_k_vector           ; Rescan K: in case HATABS reset
        raise   PS_READY
