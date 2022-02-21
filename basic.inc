; Global data

.global buffer, buffer_length

.globalzp line_ptr
.global program_start, program_end

; Functions

; arch_sim6502.s
.global getline, getchar, putline, putline_buffer, putchar

; program.s
.global initialize_program, reset_program, find_line, insert_or_upate_line

; util.s
.global copy_bytes, copy_bytes_back
