; Data structures

.struct Line
    next_line_offset .res 1
    number .res 2
    ; Following are sequences of statements consists of next_statement_offset followed by tokenized data
.endstruct

BUFFER_SIZE = 256

; Zero Page

.globalzp B
.globalzp BC
.globalzp C
.globalzp D
.globalzp DE
.globalzp E

.globalzp buffer_pos
.globalzp dst_ptr
.globalzp free_ptr
.globalzp himem_ptr
.globalzp line_number
.globalzp line_ptr
.globalzp program_ptr
.globalzp size
.globalzp src_ptr

; Data

.global buffer
.global line_buffer

; Functions

; main.s
.global main

; parser.s
.global read_number, char_to_digit
.global parse_keyword
.global skip_whitespace

; program.s
.global initialize_program
.global reset_program_state
.global reset_line_ptr
.global append_null_line
.global find_line
.global advance_line_ptr
.global insert_or_update_line
.global set_variable_value_ptr
.global set_variable_value
.global grow, grow_a, shrink, shrink_a

; run.s
.global exec_run
.global run_line
.global invoke_statement_handler
.global get_argument_value

; tables.s
.global statement_name_table

; util.s
.global copy, copy_a, copy_y_from
.global reverse_copy
.global mul10, div10

; init.s
.global initialize_target

; io.s
.global readline, write, putch, newline

; startup.s
.global startup
