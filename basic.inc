.include "constants.inc"

; Data structures

.struct Line
    next_line_offset .res 1
    number .res 2
    ; Following are sequences of statements consists of next_statement_offset followed by tokenized data
.endstruct

; Zero Page

.include "zeropage.inc"

BC = B
DE = D

; Data

.global buffer
.global line_buffer
.global op_stack
.global stack

; Functions

; decode.s
.global decode_expression
.global decode_number
.global decode_name
.global decode_byte

; encode.s
.global encode_zero
.global encode_byte

; expression.s
.global evaluate_expression
.global push_value
.global pop_value
.global stack_alloc
.global stack_free

; input.s
.global exec_input

; let.s
.global exec_let
.global assign_variable

; list.s
.global exec_list
.global list_line
.global list_statement
.global list_directive

; main.s
.global main

; name.s
.global find_name, find_name_2
.global match_name
.global initialize_name_ptr
.global advance_name_ptr
.global rebase_name_ptr
.global find_or_add_variable
.global add_variable

; parser.s
.global parse_line
.global parse_statement
.global parse_directive
.global parse_argument_list
.global parse_expression
.global parse_name
.global parse_number
.global parse_argument_separator

; print.s
.global exec_print

; program.s
.global initialize_program
.global reset_program_state
.global reset_line_ptr
.global append_null_line
.global find_line
.global advance_line_ptr
.global insert_or_update_line
.global grow, grow_a, shrink, shrink_a

; run.s
.global exec_run
.global run_line
.global invoke_statement_handler

; tables.s
.global statement_name_table
.global operator_name_table
.global unary_operator_name_table
.global operator_precedence_table

; util.s
.global copy, copy_a, copy_y_from
.global reverse_copy
.global clear_memory
.global mul2a, mul2, mul10, div10
.global invoke_indexed_vector
.global read_number, char_to_digit
.global format_number
.global find_printable_character

; target/*
.global startup, initialize_target, readline, write, putch, newline
