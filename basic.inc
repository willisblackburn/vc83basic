; Data structures
.struct Line
    next_line_offset .res 1
    number .res 2
    ; data consists of next_statement_offset followed by tokenized data
    data .res 1
.endstruct

; Zero Page

.globalzp BC, B, C, DE, D, E
.globalzp bp
.globalzp src_ptr, dst_ptr
.globalzp size
.globalzp program_ptr
.globalzp line_ptr
.globalzp free_ptr
.globalzp himem_ptr
.globalzp line_number

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
.global reset_program_state
.global reset_line_ptr
.global find_line, find_line_continue
.global advance_line_ptr, advance_line_ptr_a
.global insert_or_update_line
.global set_variable_value_ptr
.global set_variable_value
.global grow, grow_a, shrink, shrink_a
.global calculate_bytes_to_move
.global check_himem

; run.s
.global exec_run
.global run_line
.global invoke_statement_handler
.global get_argument_value

; tables.s
.global statement_name_table

; util.s
.global copy_down, copy_down_a, copy_down_size
.global copy_up, copy_up_size
.global mul10, div10

; target/*
.global startup, initialize_target, readline, getchar, write, putchar, newline
