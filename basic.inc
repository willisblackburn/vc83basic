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

; encode.s
.global encode_number
.global encode_variable
.global encode_byte

; name.s
.global find_name
.global match_character_sequence
.global is_name_character
.global add_variable

; parser.s
.global read_number, char_to_digit
.global parse_element
.global parse_arguments
.global parse_expression
.global parse_argument_separator
.global skip_whitespace ; TODO: remove once no longer needed in main

; program.s
.global initialize_program, reset_line_ptr, find_line, find_line_number, advance_line_ptr
.global delete_line, insert_line
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
NT_2ARG             = NT_1ARG + 1
NT_3ARG             = NT_1ARG + 2
NT_END_OF_ENTRY     = $80

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

; Macros

; Inserts a BRK instruction followed by a value.
; On the sim6502 platform the BRK will print the value followed by the 6502 registers.

.macro debug value
        brk
        .byte   value
.endmacro

; Loads or stores a 16-bit value to/from AX.

.macro ldax address
    .if (.match (.left (1, {address}), #))
            lda     #<(.right (.tcount ({address})-1, {address}))
            ldx     #>(.right (.tcount ({address})-1, {address}))
    .else
            lda     address
            ldx     address+1
    .endif
.endmacro

.macro stax address
        sta     address
        stx     address+1
.endmacro

; Moves an 8-bit value through A, X, or Y.

.macro mva from, to
        lda     from
        sta     to
.endmacro

.macro mvx from, to
        ldx     from
        stx     to
.endmacro

.macro mvy from, to
        ldy     from
        sty     to
.endmacro

; Moves a 16-bit value through A.

.macro mvaa from, to
    .if (.match (.left (1, {from}), #))
            lda     #<(.right (.tcount ({from})-1, {from}))
            sta     to
            lda     #>(.right (.tcount ({from})-1, {from}))
            sta     to+1
    .else
            lda     from
            sta     to
            lda     from+1
            sta     to+1
    .endif
.endmacro

; Moves a 16-bit value through AX.

.macro mvax from, to
        ldax    from
        stax    to
.endmacro
