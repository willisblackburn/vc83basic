; Declarations for target-specific code.

; Zero Page

.globalzp BC, B, C, DE, D, E

; Data

.global buffer
.global line_buffer

; Functions

.global startup, main
.global initialize_target, readline, getchar, write, putchar, newline
