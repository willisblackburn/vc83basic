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
    type .res 1
    end_value .res .sizeof(Float)
    step_value .res .sizeof(Float)
.endstruct

.struct Value
    .union
        .struct
            number_value .res .sizeof(Float)
        .endstruct
        .struct
            string_value_ptr .res 2
        .endstruct
    .endunion
    type .res 1
.endstruct

.struct Savepoint 
    type .res 1
    buffer_pos .res 1
    pvm_program_ptr .res 2
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

S0 = FPX
S1 = FPX+2

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

; dim.s
.global exec_dim

; decode.s
.global decode_expression
.global decode_number
.global decode_string
.global decode_name
.global decode_byte
.global peek_decode_byte

; encode.s
.global encode_zero
.global encode_byte

; expression.s
.global evaluate_expression
.global evaluate_argument_list
.global evaluate_variable, evaluate_decoded_variable
.global call_binary_operator
.global push_value_0, push_value_1
.global push_fp0, pop_fp0
.global push_string, pop_string
.global stack_alloc, stack_alloc_value
.global stack_free, stack_free_value, stack_free_value_with_type
.global op_add, op_sub, op_mul, op_div

; fp.s
.global fp_one, fp_ten
.global load_fp0, load_fp1
.global store_fp0
.global swap_fp0_fp1
.global copy_fp0_fp1
.global clear_fp0
.global int_to_fp, int32_to_fp
.global truncate_fp_to_int, truncate_fp_to_int32
.global round
.global truncate
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
.global fpoly, fpoly_odd
.global flog
.global fexp
.global fcos
.global fsin
.global ftan

; functions.s
.global fun_abs
.global fun_adr
.global fun_asc
.global fun_chr_s
.global fun_fre
.global fun_int
.global fun_left_s
.global fun_right_s
.global fun_mid_s
.global fun_len
.global fun_peek
.global fun_round
.global fun_sgn
.global fun_sqr
.global fun_str_s
.global fun_usr
.global fun_val
.global fun_log
.global fun_exp
.global fun_sin
.global fun_cos
.global fun_tan

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
.global get_name
.global initialize_name_ptr
.global advance_name_ptr
.global rebase_name_ptr
.global find_or_add_variable
.global add_variable
.global dimension_array
.global find_array_element
.global imul_16

; parser.s
.global parse_line
.global parse_statement
.global parse_directive
.global parse_variable
.global parse_argument_list
.global parse_expression
.global parse_name
.global parse_number
.global parse_argument_separator
.global new_parse_statement

; poke.s
.global exec_poke

; print.s
.global exec_print
.global print_number
.global print_string
.global print_newline

; program.s
.global initialize_program
.global clear_variables
.global reset_stack_pointers
.global reset_program
.global reset_data
.global reset_next_line_ptr, reset_next_line_ptr_2
.global append_null_line
.global find_line, get_line
.global advance_next_line_ptr
.global insert_or_update_line
.global grow, grow_a, shrink, shrink_a

; read.s
.global exec_read
.global exec_restore
.global exec_data
.global exec_rem

; run.s
.global exec_run
.global exec_end
.global exec_stop
.global exec_cont
.global exec_new
.global exec_clr

; string.s
.global load_s0, load_s1
.global read_string
.global string_alloc
.global compact

; tables.s
.global statement_name_table
.global operator_name_table
.global unary_operator_name_table
.global function_name_table
.global function_arity_table
.global operator_precedence_table
.global type_size_table
.global error_message_table

; util.s
.global copy, copy_a, copy_y_from
.global reverse_copy
.global clear_memory, set_memory
.global invoke_indexed_vector, invoke_indexed_vector_2
.global read_argument_separator
.global find_printable_character
.global line_number_to_string
.global install_exception_handler
.global on_raise

; target/*
.global startup, initialize_target, readline, write, putch, newline
