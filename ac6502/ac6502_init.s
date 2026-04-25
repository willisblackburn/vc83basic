; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn / 2026 A.C. Wright
;
; SPDX-License-Identifier: MIT
;
; ac6502 BASIC workspace (buffers and interpreter stacks).  All mutable
; storage is placed in the BSS segment so __BSS_SIZE__ correctly reflects
; how much RAM is consumed before the user program area.  BASIC's
; program_ptr is computed from __BSS_RUN__ + __BSS_SIZE__ (see program.s).
; 
; See https://github.com/acwright/6502 for more info

.segment "BSS"

; Align to a page boundary so that `stack` (which follows two
; page-sized buffers) lands on a page boundary.  control.s asserts
; `<stack = 0`.
.align  $100

buffer:         .res BUFFER_SIZE
line_buffer:    .res BUFFER_SIZE

; Ensure that primary stack and operator stack fit together in one page.
.assert PRIMARY_STACK_SIZE + OP_STACK_SIZE = 208, error

stack:          .res PRIMARY_STACK_SIZE
op_stack:       .res OP_STACK_SIZE

.code
