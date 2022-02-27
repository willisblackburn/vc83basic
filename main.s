; cc65 runtime
.include "zeropage.inc"
.import push0, push1, pushax, return0

.import readline, write, write_buffer, putchar, newline

; Main entry point for BASIC.
; Return from this function returns control to startup.

message: .byte "ENTER YOUR NAME: "
message_length = * - message
hello: .byte "HELLO, "
hello_length = * - hello

main:
.export main
        lda     #<message       ; Print message
        ldx     #>message
        ldy     #message_length
        jsr     write           ; Write the message
        jsr     readline        ; Get the user's input
        lda     #<hello         ; Hello message pointer
        ldx     #>hello
        ldy     #hello_length
        jsr     write           ; Write "hello"
        jsr     write_buffer    ; Output name (still in buffer)
        jsr     newline         ; Write linefeed
        jmp     return0
