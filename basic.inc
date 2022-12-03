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
    variable .res 1
    end_value .res 2
    step_value .res 2
.endstruct

.struct Float
    e .res 1    ; Exponent
    s .res 4    ; Significand
.endstruct

; Zero Page

.globalzp BC, B, C, DE, D, E
.globalzp FPA
.globalzp FP0, FP0e, FP0s, FP0x, FP1, FP1e, FP1s, FP1x
.globalzp grs
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
.global push_value, pop_value
.global stack_alloc, stack_free

; fp.s
.global load_fpa, store_fpa, clear_fpa
.global swap_fpa
.global fpa_is_zero
.global fneg
.global fp_to_string
.global string_to_fp
.global char_to_digit
.global int_to_fp
.global truncate_fp_to_int
.global fadd, fadd_with_ptr
.global fsub, fsub_with_ptr
.global fmul, fmul_with_ptr
.global fdiv, fdiv_with_ptr
.global fcmp, fcmp_with_ptr

.global load_fp0
.global store_fp0
.global swap_fp0_fp1
.global int_to_fp2
.global truncate_fp_to_int2
.global normalize
.global fadd2

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
.global dispatch_next_statement

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
.global read_number
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
.global set_variable_value

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
.global copy_bytes, copy_bytes_a, copy_bytes_de, copy_bytes_higher, copy_bytes_higher_a, copy_bytes_higher_de
.global clear_memory
.global mul2a, mul2, mul10, div10
.global invoke_indexed_vector
.global format_number

; target/*
.global startup, initialize_target, readline, getchar, write, putchar, newline
