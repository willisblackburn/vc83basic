  

; Generated from constants.m4

; Name table definitions 

NT_VAR = $10
NT_RPT_VAR = $11
NT_NUM = $12
NT_RPT_NUM = $13
NT_STATEMENT = $14
NT_END = $80

; Tokenized form constants

TOKEN_NO_VALUE = $00
TOKEN_PAREN = $01
TOKEN_UNARY_OP = $08 ; OR with OP_UNARY_*
TOKEN_OP = $10 ; OR with OP_*
TOKEN_NUM = $20
TOKEN_VAR = $80 ; OR with variable number

; Statement tokens

ST_END = 0
ST_RUN = 1
ST_PRINT = 2
ST_LET = 3
ST_INPUT = 4
ST_LIST = 5
ST_GOTO = 6
ST_GOSUB = 7
ST_RETURN = 8
ST_POP = 9
ST_ON_GOTO = 10
ST_ON_GOSUB = 11
ST_FOR = 12
ST_NEXT = 13
ST_STOP = 14
ST_CONT = 15
ST_IF_THEN = 16

; Binary operator tokens: combine with TOKEN_OP

OP_ADD = 0
OP_SUB = 1
OP_MUL = 2
OP_DIV = 3
OP_POW = 4
OP_CONCAT = 5
OP_EQ = 6
OP_LT = 7
OP_GT = 8
OP_NE = 9
OP_LE = 10
OP_GE = 11
OP_AND = 12
OP_OR = 13

; Binary operator tokens: combine with TOKEN_UNARY_OP

UNARY_OP_MINUS = 0
UNARY_OP_NOT = 1

; Expression decode handlers

XH_VAR = 0
XH_NUM = 1
XH_OP = 2
XH_UNARY_OP = 3
XH_PAREN = 4

; Expression precedence levels

PR_UNARY_OP = $F0
PR_POW = $C0
PR_MUL = $A0
PR_ADD = $80
PR_RELATIONAL = $60
PR_LOGICAL = $40
PR_CLOSE_PAREN = $20
PR_OPEN_PAREN = $00

; Program states

PS_STOPPED = $00
PS_RUNNING = $01

; Other constants

PRIMARY_STACK_SIZE = 192
OP_STACK_SIZE = 16
