; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

.segment "BUFFERS"

buffer:         .res BUFFER_SIZE
line_buffer:    .res BUFFER_SIZE

.segment "ONCE"

initialize_target:
        ; Initialize expression stack positions (BSS is not zeroed on bare metal)
        lda     #PRIMARY_STACK_SIZE
        sta     stack_pos
        lda     #OP_STACK_SIZE
        sta     op_stack_pos

        ; RAM ends at $7FFF on Replica-1, APL1, and most Apple 1 replicas
        mvax    #$8000, himem_ptr

        ; WozMon leaves the cursor on the same line as the "4000R" command,
        ; so output a newline before the banner to start on a fresh line.
        jsr     newline
        jmp     display_startup_banner

.bss

.align 256
stack:          .res PRIMARY_STACK_SIZE
op_stack:       .res OP_STACK_SIZE

.code
