.include "constants.inc"

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
.globalzp name_bp
.globalzp name_ptr
.globalzp np
.globalzp matched_name_index
.globalzp src_ptr, dst_ptr
.globalzp size
.globalzp vector_table_ptr
.globalzp program_ptr
.globalzp line_ptr
.globalzp variable_name_table_ptr
.globalzp value_table_ptr
.globalzp free_ptr
.globalzp himem_ptr
.globalzp variable_count
.globalzp variable_value_ptr
.globalzp lp
.globalzp program_state
.globalzp line_number
.globalzp argument_count

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
.global encode_no_value
.global encode_byte

; input.s
.global exec_input

; let.s
.global exec_let

; list.s
.global exec_list
.global list_line
.global list_statement
.global list_name
.global list_directive

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
.global parse_argument_separator
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
.global calculate_bytes_to_move
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
.global copy_down, copy_down_a, copy_down_size
.global copy_up, copy_up_size
.global clear_memory
.global mul2a, mul2, mul10, div10
.global invoke_indexed_vector
.global format_number

; target/*
.global startup, initialize_target, readline, getchar, write, putchar, newline
