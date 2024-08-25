.include "constants.inc"

; Data structures

.struct Line
    next_line_offset .res 1
    number .res 2
    ; data consists of next_statement_offset followed by tokenized data
    data .res 1
.endstruct

; Zero Page

.include "zeropage.inc"

BC = B
DE = D

; Data

.global buffer
.global line_buffer

; Functions

; decode.s
.global decode_number
.global decode_name
.global decode_byte

; encode.s
.global encode_number
.global encode_no_value
.global encode_byte

; expression.s
.global evaluate_expression

; input.s
.global exec_input

; let.s
.global exec_let
.global assign_variable

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
.global advance_node_ptr
.global rebase_node_ptr
.global find_or_add_variable
.global add_variable

; parser.s
.global read_number, char_to_digit
.global parse_line
.global parse_statement
.global parse_directive
.global parse_expression
.global parse_name
.global parse_argument_separator
.global skip_whitespace

; print.s
.global exec_print

; program.s
.global initialize_program
.global reset_program_state
.global reset_line_ptr
.global find_line
.global advance_line_ptr, advance_line_ptr_a
.global insert_or_update_line
.global grow, grow_a, shrink, shrink_a
.global check_himem

; run.s
.global exec_run
.global run_line
.global invoke_statement_handler

; tables.s
.global statement_name_table

; util.s
.global copy, copy_a, copy_size
.global reverse_copy, reverse_copy_size
.global clear_memory, clear_memory_size
.global mul2a, mul2, mul10, div10
.global invoke_indexed_vector
.global format_number

; target/*
.global startup, initialize_target, readline, write, putch, newline
