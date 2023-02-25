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

.globalzp BC, B, C, DE, D, E
.globalzp FP0, FP0t, FP0e, FP0s, FP1, FP1t, FP1e, FP1s, FP2, FP3
.globalzp bp
.globalzp name_ptr
.globalzp np
.globalzp src_ptr, dst_ptr
.globalzp vector_table_ptr
.globalzp program_ptr
.globalzp line_ptr
.globalzp next_line_ptr
.globalzp variable_name_table_ptr
.globalzp value_table_ptr
.globalzp free_ptr
.globalzp himem_ptr
.globalzp variable_count
.globalzp variable_value_ptr
.globalzp lp
.globalzp program_state
.globalzp argument_count
.globalzp osp
.globalzp psp
.globalzp resume_line_ptr

; Data

.global buffer
.global line_buffer
.global primary_stack
.global op_stack

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
.global list_element
.global list_directive

; main.s
.global main
.global dispatch_statement

; name.s
.global find_name
.global find_next_name
.global match_character_sequence
.global read_name_table_byte
.global is_name_character
.global advance_name_ptr
.global get_name_table_entry
.global add_variable

; parser.s
.global parse_line
.global parse_element
.global parse_next_element
.global parse_directive
.global parse_expression
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
.global find_line
.global advance_next_line_ptr
.global insert_or_update_line
.global expand, expand_a, compact, compact_a
.global calculate_bytes_to_move
.global check_himem
.global set_variable_value_ptr

; run.s
.global exec_run
.global exec_end
.global exec_stop
.global exec_cont

; tables.s
.global statement_name_table
.global operator_name_table
.global operator_precedence_table
.global unary_operator_name_table

; util.s
.global copy_bytes, copy_bytes_de
.global copy_bytes_y, copy_bytes_a
.global copy_bytes_higher, copy_bytes_higher_de
.global clear_memory, clear_memory_de
.global clear_memory_a, clear_memory_y
.global mul8a, mul8
.global invoke_indexed_vector
.global advance_lp_sizeof_float, advance_lp

; target/*
.global startup, initialize_target, readline, getchar, write, putchar, newline
