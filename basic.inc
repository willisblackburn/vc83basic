; Global data

.global buffer, buffer_length

.globalzp line_ptr
.global program_start, program_end

; Functions

; arch_sim6502.s
.global initialize_arch, getline, getchar, putline, putline_buffer, putchar

; program.s
.global initialize_program, reset_line_ptr, find_line, advance_line_ptr, insert_or_upate_line

; util.s
.global copy_bytes, copy_bytes_back
