; Global data

.include "target.inc"

.globalzp r

.globalzp copy_from_ptr, copy_to_ptr, copy_length
.globalzp line_ptr
.global program_ptr
.global heap_ptr

.globalzp status

; Status and error codes

STATUS_OK                   = $00   ; Everything OK; used to clear status
ERR_FAIL                    = $FF   ; General failure

; Functions

; parser.s
.global read_number, char_to_digit
.global parse_keyword
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
