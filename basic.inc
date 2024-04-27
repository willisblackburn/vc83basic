.include "constants.inc"

; Data structures
.struct Line
    next_line_offset .res 1
    number .res 2
    ; data consists of next_statement_offset followed by tokenized data
    data .res 1
.endstruct

; Zero Page

.globalzp B
.globalzp BC
.globalzp C
.globalzp D
.globalzp DE
.globalzp E

.globalzp buffer_pos
.globalzp dst_ptr
.globalzp free_ptr
.globalzp himem_ptr
.globalzp line_number
.globalzp line_ptr
.globalzp line_pos
.globalzp matched_name_index
.globalzp name_start_pos
.globalzp name_ptr
.globalzp name_pos
.globalzp program_ptr
.globalzp size
.globalzp src_ptr
.globalzp value_table_ptr
.globalzp variable_count
.globalzp variable_name_table_ptr
.globalzp variable_value_ptr
.globalzp vector_table_ptr

; Data

.global buffer
.global line_buffer

; Functions

; decode.s
.global decode_number
.global decode_variable
.global decode_byte

; encode.s
.global encode_number
.global encode_variable
.global encode_byte

; let.s
.global exec_let

; main.s
.global main

; name.s
.global find_name
.global match_name
.global read_name_table_byte
.global advance_name_ptr
.global get_name_table_entry
.global add_variable

; parser.s
.global read_number, char_to_digit
.global parse_line
.global parse_statement
.global parse_directive
.global parse_expression
.global parse_name
.global is_name_character
.global skip_whitespace

; print.s
.global exec_print

; program.s
.global initialize_program
.global reset_program_state
.global reset_line_ptr
.global find_line, find_line_continue
.global advance_line_ptr, advance_line_ptr_a
.global insert_or_update_line
.global grow, grow_a, shrink, shrink_a
.global check_himem
.global set_variable_value_ptr
.global set_variable_value

; run.s
.global exec_run
.global run_line
.global invoke_statement_handler
.global get_argument_value

; tables.s
.global statement_name_table

; util.s
.global copy, copy_a, copy_size
.global reverse_copy, reverse_copy_size
.global clear_memory
.global mul2a, mul2, mul10, div10
.global invoke_indexed_vector
.global format_number

; target/*
.global startup, initialize_target, readline, write, putch, newline
