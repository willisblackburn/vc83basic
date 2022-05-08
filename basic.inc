; Zero Page

.globalzp status
.globalzp r
.globalzp w
.globalzp name_ptr
.globalzp signature_ptr
.globalzp argument_index
.globalzp copy_from_ptr, copy_to_ptr, copy_length
.globalzp line_ptr, line_length, line_number
.globalzp program_ptr
.globalzp variable_name_table_ptr
.globalzp value_table_ptr
.globalzp heap_ptr
.globalzp himem_ptr
.globalzp variable_count

; Data

.global statement_name_table
.global statement_signature_table

; Functions

; decode.s
.global decode_number

; encode.s
.global encode_number
.global encode_variable
.global encode_byte

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
.global skip_whitespace ; TODO: remove once no longer needed in main

; program.s
.global initialize_program, reset_line_ptr, find_line, find_line_sreg, advance_line_ptr, update_line_fields
.global delete_line, insert_line, insert_line_sreg
.global get_line_start, get_line_start_plus_a, get_line_ptr_plus_a
.global grow_a, grow_ay, check_himem

; util.s
.global copy_bytes, copy_bytes_back
.global return_error, return_internal_error, return_status, return_status_ok
.global mul10, div10
.global invoke_indexed_vector

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

; Status and error codes

STATUS_OK                   = $00   ; Everything OK; used to clear status
ERR_FAIL                    = $FF   ; General failure
