; Data structures
.struct Line
    next_line_offset .res 1
    number .res 2
    ; data consists of next_statement_offset followed by tokenized data
    data .res 1
.endstruct

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
.global line_buffer

; Functions

; main.s
.global main

; parser.s
.global read_number, char_to_digit
.global parse_keyword
.global skip_whitespace

; program.s
.global initialize_program
.global reset_line_ptr
.global find_line
.global advance_line_ptr
.global add_line_ptr_offset
.global insert_or_update_line

; util.s
.global copy_bytes, copy_bytes_de, copy_bytes_back, copy_bytes_back_de
.global mul10, div10

; target/*
.global startup, initialize_target, readline, getchar, write, putchar, newline
