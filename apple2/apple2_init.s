.include "../macros.inc"
.include "../basic.inc"

initialize_target:
        rts

; Buffers

buffer := $200
line_buffer := $300

.segment "BUFFERS"

; Primary stack
primary_stack: .res PRIMARY_STACK_SIZE
; Operator stack
op_stack: .res OP_STACK_SIZE
