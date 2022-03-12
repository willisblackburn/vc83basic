; Global data

.include "target.inc"

; Globals

.globalzp r
.globalzp w

.globalzp line_ptr
.global program_start, program_end

.globalzp status

.globalzp name_table
.globalzp name_index
.globalzp save_name_table_byte

.global statement_name_table

.globalzp copy_from, copy_to, copy_length

; Value types

TYPE_NONE           = $00
TYPE_INT            = $01
TYPE_FLOAT          = $02
TYPE_STRING         = $04
TYPE_ANY            = $07
TYPE_VAR            = $08
TYPE_CH             = $09
TYPE_INPUT          = $0A
TYPE_PRINT          = $0B
TYPE_THEN           = $0C
TYPE_STEP           = $0D
TYPE_IGNORE         = $0F

; Type modifiers

TYPE_OPTIONAL       = $10
TYPE_REPEATED       = $20

; Name table definitions 

NT_1ARG             = $01
NT_2ARG             = NT_1ARG + 1
NT_3ARG             = NT_1ARG + 2
NT_END              = $80

; Status and error codes

STATUS_OK                   = $00   ; Everything OK; used to clear status
ERR_FAIL                    = $FF   ; General failure

; Statements
; Must match statement_name_table.

ST_LIST     = 0
ST_RUN      = 1
ST_PRINT    = 2

; Functions

; name.s
.global find_name, advance_y_next_name

; parser.s
.global parse_number, char_to_digit
.global skip_whitespace

; program.s
.global initialize_program, reset_line_ptr, find_line, advance_line_ptr, insert_or_update_line
.global get_line_start, get_line_start_plus_a, get_line_ptr_plus_a

; util.s
.global copy_bytes, copy_bytes_back
.global return_error, return_internal_error, return_status, return_status_ok
.global mul10, div10

; Macros

; Inserts a BRK instruction followed by a value.
; On the sim6502 platform the BRK will print the value followed by the 6502 registers.

.macro  debug   value
        brk
        .byte   value
.endmacro
