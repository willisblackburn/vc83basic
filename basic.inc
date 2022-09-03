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
.globalzp name_ptr
.globalzp np
.globalzp src_ptr, dst_ptr
.globalzp program_ptr
.globalzp line_ptr
.globalzp variable_name_table_ptr
.globalzp value_table_ptr
.globalzp heap_ptr
.globalzp free_ptr
.globalzp himem_ptr
.globalzp variable_count
.globalzp variable_value_ptr
.globalzp lp
.globalzp program_state
.globalzp argument_count

; Data

.global buffer
.global line_buffer

; Functions

; decode.s
.global decode_number
.global decode_byte

; encode.s
.global encode_number
.global encode_variable
.global encode_byte

; input.s
.global exec_input

; let.s
.global exec_let

; list.s
.global exec_list
.global list_line
.global list_element
.global list_argument
.global list_multiple_arguments
.global list_repeated_argument

; main.s
.global main

; name.s
.global find_name
.global match_character_sequence
.global is_name_character
.global get_name_table_entry
.global add_variable

; parser.s
.global read_number, char_to_digit
.global parse_line
.global parse_element
.global parse_multiple_arguments
.global parse_repeated_argument
.global parse_argument
.global parse_expression
.global parse_argument_separator
.global skip_whitespace

; print.s
.global exec_print

; program.s
.global initialize_program
.global reset_program_state
.global reset_line_ptr
.global find_line
.global advance_line_ptr
.global add_line_ptr_offset
.global insert_or_update_line
.global set_variable_value_ptr
.global set_variable_value
.global expand, expand_a, compact, compact_a
.global calculate_bytes_to_move
.global check_himem

; run.s
.global exec_run
.global run_line
.global invoke_statement_handler
.global get_argument_value

; tables.s
.global statement_name_table
.global statement_exec_vectors

; util.s
.global copy_bytes, copy_bytes_a, copy_bytes_de, copy_bytes_higher, copy_bytes_higher_a, copy_bytes_higher_de
.global clear_memory
.global mul2a, mul2, mul10, div10
.global invoke_indexed_vector, invoke_indexed_vector_vt
.global format_number
.global putchar_space_buffer, putchar_buffer

; target/*
.global startup, initialize_target, readline, getchar, write, putchar, newline
