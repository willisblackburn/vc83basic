; Zero Page

.globalzp BC, B, C, DE, D, E
.globalzp status
.globalzp r
.globalzp src_ptr, dst_ptr
.globalzp line_ptr
.globalzp program_ptr
.globalzp heap_ptr


; Data

.global buffer

; Functions

; main.s
.global main

; parser.s
.global read_number, char_to_digit
.global parse_keyword
.global skip_whitespace

; program.s
.global initialize_program, reset_line_ptr, find_line, advance_line_ptr, insert_or_update_line
.global get_line_start, get_line_start_plus_a, get_line_ptr_plus_a

; util.s
.global copy_bytes, copy_bytes_de, copy_bytes_back, copy_bytes_back_de
.global return_error, return_internal_error, return_status, return_status_ok
.global mul10, div10

; target/*
.global startup, initialize_target, readline, getchar, write, putchar, newline

; Status and error codes

STATUS_OK                   = $00   ; Everything OK; used to clear status
ERR_FAIL                    = $FF   ; General failure
