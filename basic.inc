.include "constants.inc"

; Data structures

.struct Line
    next_line_offset .res 1
    number .res 2
    ; data consists of next_statement_offset followed by tokenized data
    data .res 1
.endstruct

.struct Float
    t .res 4
    e .res 1
.endstruct

.struct UnpackedFloat
    t .res 4
    e .res 1
    s .res 1
.endstruct

.struct Control
    next_line_ptr .res 2
    variable .res 1
    end_value .res .sizeof(Float)
    step_value .res .sizeof(Float)
.endstruct

; Zero Page

.globalzp B
.globalzp BC
.globalzp C
.globalzp D
.globalzp DE
.globalzp E
.globalzp FP0
.globalzp FP0e
.globalzp FP0s
.globalzp FP0t
.globalzp FP1
.globalzp FP1e
.globalzp FP1s
.globalzp FP1t
.globalzp FP2
.globalzp FP3
.globalzp argument_count
.globalzp bp
.globalzp decode_expression_vector_table_ptr
.globalzp dst_ptr
.globalzp fp_temp
.globalzp free_ptr
.globalzp himem_ptr
.globalzp line_number
.globalzp line_ptr
.globalzp lp
.globalzp matched_name_index
.globalzp min_precedence
.globalzp name_bp
.globalzp name_ptr
.globalzp next_line_ptr
.globalzp np
.globalzp on_handler
.globalzp on_value
.globalzp osp
.globalzp program_ptr
.globalzp program_state
.globalzp psp
.globalzp resume_line_ptr
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
.global exec_if

; decode.s
.global decode_expression
.global decode_number
.global decode_int
.global decode_variable
.global decode_operator
.global decode_unary_operator
.global decode_byte

; encode.s
.global encode_number
.global encode_variable
.global encode_operator
.global encode_unary_operator
.global encode_no_value
.global encode_byte

; expression.s
.global evaluate_expression
.global call_binary_operator
.global push_fpx, push_fp0, pop_fpx, pop_fp0
.global push_variable, pop_variable
.global stack_alloc, stack_free

; fp.s
.global fp_one, fp_ten
.global load_fpx, load_fp0
.global store_fpx, store_fp0
.global swap_fp0_fp1
.global copy_fp0_fp1
.global fpx_is_zero, fp0_is_zero
.global clear_fpx, clear_fp0
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

; list.s
.global exec_list
.global list_line
.global list_statement
.global list_name
.global list_directive

; main.s
.global main
.global dispatch_statement

; name.s
.global find_name
.global find_next_name
.global match_name
.global read_name_table_byte
.global advance_name_ptr
.global get_name_table_entry
.global add_variable

; parser.s
.global parse_line
.global parse_statement
.global parse_directive
.global parse_expression
.global parse_argument_separator
.global parse_name
.global is_name_character
.global parse_operator_name
.global is_operator_name_character
.global skip_whitespace

; print.s
.global exec_print
.global print_number

; program.s
.global initialize_program
.global reset_program_state
.global reset_next_line_ptr
.global build_end_statement
.global find_line, find_line_continue
.global advance_next_line_ptr
.global insert_or_update_line
.global grow, grow_a, shrink, shrink_a
.global check_himem
.global set_variable_value_ptr
.global mul_value_size, mul_value_size_a
.global initialize_variable

; run.s
.global exec_run
.global exec_end
.global exec_stop
.global exec_cont

; tables.s
.global statement_name_table
.global operator_name_table
.global operator_chars
.global operator_chars_end
.global operator_precedence_table
.global unary_operator_name_table

; util.s
.global copy, copy_a, copy_size
.global reverse_copy, reverse_copy_size
.global invoke_indexed_vector
.global advance_lp_sizeof_float, advance_lp

; target/*
.global startup, initialize_target, readline, write, putch, newline
