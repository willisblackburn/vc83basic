  

; Generated from constants.m4

TYPE_NONE = $00
TYPE_INT = $01
TYPE_FLOAT = $02
TYPE_STRING = $04
TYPE_ANY = $07
TYPE_VAR = $08
TYPE_CH = $09
TYPE_PROMPT = $0A
TYPE_PRINT = $0B
TYPE_THEN = $0C
TYPE_STEP = $0D
TYPE_IGNORE = $0E

; Type modifiers

TYPE_REPEATED = $20
TYPE_REQUIRED = $40
TYPE_END = $80

TYPE_MASK_TYPE_ONLY = $0F
TYPE_MASK_CLEAR_REPEATED = $DF

; Name table definitions 

NT_END = $80

; Tokenized form constants

TOKEN_END_OF_LINE = $00
TOKEN_NO_VALUE = $01
TOKEN_INT = $02
TOKEN_FLOAT = $03
TOKEN_STRING = $04

; Statements
; Must match statement_name_table.

ST_LIST = 0
ST_RUN = 1
ST_PRINT = 2
ST_LET = 3
ST_INPUT = 4
ST_DATA = 5
ST_READ = 6
ST_RESTORE = 7

; Status and error codes

STATUS_OK = $00
ERR_FAIL = $FF
