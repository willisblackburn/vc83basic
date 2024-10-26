.include "constants.inc"

; Data structures

.struct Line
    next_line_offset .res 1
    number .res 2
    ; data consists of next_statement_offset followed by tokenized data
    data .res 1
.endstruct

.struct Control
    next_line_ptr .res 2
    variable_name_ptr .res 2
    end_value .res 2
    step_value .res 2
.endstruct

; Zero Page

.include "zeropage.inc"

BC = B
DE = D

; Data

.global buffer
.global line_buffer
.global op_stack
.global primary_stack

; Functions

; control.s
.global exec_goto
.global exec_on_goto
.global exec_gosub
.global exec_on_gosub
.global exec_return
.global exec_for
.global exec_next
.global exec_pop

; decode.s
.global decode_expression
.global decode_number
.global decode_name
.global decode_operator
.global decode_unary_operator
.global decode_byte

; encode.s
.global encode_operator
.global encode_unary_operator
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
.global list_name
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
.global parse_expression
.global parse_name
.global parse_number
.global parse_argument_separator
.global skip_whitespace

; print.s
.global exec_print
.global print_number

; program.s
.global initialize_program
.global reset_program_state
.global reset_next_line_ptr
.global build_end_statement
.global find_line, find_line_2
.global advance_next_line_ptr
.global insert_or_update_line
.global grow, grow_a, shrink, shrink_a

; run.s
.global exec_run
.global exec_end
.global exec_stop
.global exec_cont

; tables.s
.global statement_name_table
.global operator_name_table
.global unary_operator_name_table
.global operator_precedence_table

; util.s
.global copy, copy_a, copy_size
.global reverse_copy, reverse_copy_size
.global clear_memory, clear_memory_size
.global mul2a, mul2, mul10, div10
.global invoke_indexed_vector
.global read_number, char_to_digit
.global format_number

; target/*
.global startup, initialize_target, readline, write, putch, newline
