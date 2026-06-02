; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

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

.segment "ONCE"     

initialize_target_apple2:        
        lda     #$FF                    ; Print in normal mode
        sta     COUTMASK
        mvax    #reset_handler, SOFTEV  ; RESET button returns control to this program
        mva     #(>reset_handler ^ $A5), PWREDUP        
        jsr     HOME                    ; Clear screen
        jmp     display_startup_banner

.code
