; Data structures
.struct Line
    next_line_offset .res 1
    number .res 2
    ; data consists of next_statement_offset followed by tokenized data
    data .res 1
.endstruct

; Zero Page

.globalzp BC, B, C, DE, D, E
.globalzp status
.globalzp r
.globalzp w
.globalzp name_ptr
.globalzp n
.globalzp signature_ptr
.globalzp argument_count
.globalzp argument_index
.globalzp src_ptr, dst_ptr
.globalzp line_ptr
.globalzp program_ptr
.globalzp variable_name_table_ptr
.globalzp value_table_ptr
.globalzp heap_ptr
.globalzp himem_ptr
.globalzp variable_count
.globalzp variable_value_ptr

; Data

.global buffer
.global line_buffer

; Functions

; data.s
.global exec_read
.global exec_restore
.global exec_data

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
.global add_whitespace

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
.global parse_element
.global parse_arguments
.global parse_expression
.global parse_argument_separator
.global skip_whitespace

; print.s
.global exec_print

; program.s
.global initialize_program
.global reset_line_ptr
.global find_line
.global advance_line_ptr
.global add_line_ptr_offset
.global insert_or_update_line
.global grow_varible_name_table, check_himem
.global set_variable_value_ptr
.global set_variable_value

; run.s
.global exec_run
.global invoke_statement_handler
.global get_argument_value

; tables.s
.global statement_name_table
.global statement_signature_table
.global statement_exec_vectors

; util.s
.global copy_bytes, copy_bytes_de, copy_bytes_back, copy_bytes_back_de
.global clear_memory
.global return_error, return_internal_error, return_status, return_status_ok
.global mul2a, mul2, mul10, div10
.global invoke_indexed_vector
.global format_number
.global putchar_space_buffer, putchar_buffer

; target/*
.global startup, initialize_target, readline, getchar, write, putchar, newline

; Value types

TYPE_NONE           = $00
TYPE_INT            = $01
TYPE_FLOAT          = $02
TYPE_STRING         = $04
TYPE_ANY            = $07
TYPE_VAR            = $08
TYPE_CH             = $09
TYPE_PROMPT         = $0A
TYPE_PRINT          = $0B
TYPE_THEN           = $0C
TYPE_STEP           = $0D
TYPE_IGNORE         = $0E

; Type modifiers

TYPE_OPTIONAL       = $10
TYPE_REPEATED       = $20

; Name table definitions 

NT_1ARG             = $01
NT_2ARG             = $02
NT_3ARG             = $03
NT_END              = $80

; Tokenized form constants

TOKEN_END_OF_LINE           = $00
TOKEN_END_OF_STATEMENT      = $01
TOKEN_INT                   = $02

; Statements
; Must match statement_name_table.

ST_LIST     = 0
ST_RUN      = 1
ST_PRINT    = 2
ST_LET      = 3
ST_INPUT    = 4
ST_DATA     = 5
ST_READ     = 6
ST_RESTORE  = 7

; Status and error codes

STATUS_OK                   = $00   ; Everything OK; used to clear status
ERR_FAIL                    = $FF   ; General failure
