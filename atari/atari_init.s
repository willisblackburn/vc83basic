; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
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

.code
