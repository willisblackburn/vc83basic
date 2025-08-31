.include "constants.inc"

; Data structures

.struct Float
    t .res 4
    e .res 1
.endstruct

.struct UnpackedFloat
    t .res 4
    e .res 1
    s .res 1
.endstruct

.struct Line
    next_line_offset .res 1
    number .res 2
    ; Following are sequences of statements consists of next_statement_offset followed by tokenized data
.endstruct

.struct Control
    next_line_ptr .res 2
    next_line_pos .res 1
    variable_name_ptr .res 2
    end_value .res .sizeof(Float)
    step_value .res .sizeof(Float)
.endstruct

; Zero Page

.include "zeropage.inc"

BC = B
DE = D

FP0t = FP0+UnpackedFloat::t
FP0e = FP0+UnpackedFloat::e
FP0s = FP0+UnpackedFloat::s
FP1t = FP1+UnpackedFloat::t
FP1e = FP1+UnpackedFloat::e
FP1s = FP1+UnpackedFloat::s

; Data

.global buffer
.global line_buffer
.global op_stack
.global stack

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
.global exec_if

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
.global evaluate_variable, evaluate_decoded_variable
.global call_binary_operator
.global push_fp0, pop_fp0
.global stack_alloc, stack_alloc_value
.global stack_free, stack_free_value

; fp.s
.global fp_one, fp_ten
.global load_fp0, load_fp1
.global store_fp0
.global swap_fp0_fp1
.global copy_fp0_fp1
.global clear_fp0
.global int_to_fp, int32_to_fp
.global truncate_fp_to_int, truncate_fp_to_int32
.global fp_to_string
.global string_to_fp
.global char_to_digit
.global adjust_exponent
.global normalize
.global fadd
.global fsub
.global fmul
.global fdiv
.global fneg
.global fcmp

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
.global dispatch_statement

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
.global print_number

; program.s
.global initialize_program
.global reset_program_state
.global reset_next_line_ptr, reset_next_line_ptr_2
.global append_null_line
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
.global copy, copy_a, copy_y_from
.global reverse_copy
.global clear_memory
.global invoke_indexed_vector
.global find_printable_character

; target/*
.global startup, initialize_target, readline, write, putch, newline
