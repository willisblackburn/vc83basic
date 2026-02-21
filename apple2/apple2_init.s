; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

initialize_target:
        rts

; Buffers

.segment "BUFFERS"

buffer := $200
line_buffer: .res BUFFER_SIZE

; Ensure that primary stack and operator stack fit together in unused part of page 3
.assert PRIMARY_STACK_SIZE + OP_STACK_SIZE = 208, error

; Primary stack
stack := $300
; Operator stack
op_stack := $300 + PRIMARY_STACK_SIZE

.code
