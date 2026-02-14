ifdef(`__C__',
    `define(`def', ``#define $1 $2'') define(`hex', `0x$1') define(`comment', `//')',
    `define(`def', ``$1 = $2'') define(`hex', `$$1') define(`comment', `;')')

comment Generated from __file__

comment Name table definitions 

def(NT_VAR,             hex(10))
def(NT_RPT_VAR,         hex(11))
def(NT_NUMBER,          hex(12))
def(NT_RPT_NUMBER,      hex(13))
def(NT_STATEMENT,       hex(14))
def(NT_PRINT_EXP,       hex(15))
def(NT_TEXT,            hex(16))

comment Tokenized form constants

def(TOKEN_UNARY_OP,     hex(04)) comment OR with OP_UNARY_*
def(TOKEN_CLAUSE,       hex(08)) comment OR with CLAUSE_*
def(TOKEN_OP,           hex(10)) comment OR with OP_*
def(TOKEN_FUNCTION,     hex(60)) comment OR with index of function

comment Statement tokens

def(ST_END,             0)
def(ST_RUN,             1)
def(ST_PRINT,           2)
def(ST_LET,             3)
def(ST_INPUT,           4)
def(ST_LIST,            5)
def(ST_GOTO,            6)
def(ST_GOSUB,           7)
def(ST_RETURN,          8)
def(ST_POP,             9)
def(ST_ON,             10)
def(ST_FOR,            11)
def(ST_NEXT,           12)
def(ST_STOP,           13)
def(ST_CONT,           14)
def(ST_IF_THEN,        15)
def(ST_NEW,            16)
def(ST_CLR,            17)
def(ST_DIM,            18)
def(ST_REM,            19)
def(ST_DATA,           20)
def(ST_READ,           21)
def(ST_RESTORE,        22)
def(ST_POKE,           23)

comment Binary operator tokens: combine with TOKEN_OP

def(OP_ADD,             0)
def(OP_SUB,             1)
def(OP_MUL,             2)
def(OP_DIV,             3)
def(OP_POW,             4)
def(OP_CONCAT,          5)
def(OP_EQ,              6)
def(OP_LT,              7)
def(OP_GT,              8)
def(OP_NE,              9)
def(OP_LE,             10)
def(OP_GE,             11)
def(OP_AND,            12)
def(OP_OR,             13)

comment Binary operator tokens: combine with TOKEN_UNARY_OP

def(UNARY_OP_MINUS,     0)
def(UNARY_OP_NOT,       1)

comment Non-statement extras

def(CLAUSE_THEN,        0)
def(CLAUSE_GOTO,        1)
def(CLAUSE_GOSUB,       2)
def(CLAUSE_TO,          3)
def(CLAUSE_STEP,        4)

comment Expression decode handlers

def(XH_UNARY_OP,        0)
def(XH_OP,              1)
def(XH_NUMBER,          2)
def(XH_STRING,          3)
def(XH_VAR,             4)
def(XH_FUNCTION,        5)
def(XH_PAREN,           6)

comment Types

def(TYPE_NUMBER,        hex(00))
def(TYPE_STRING,        hex(01))
def(TYPE_CONTROL,       hex(FF)) comment Only used on stack

comment Expression precedence levels

def(PR_UNARY_OP,        hex(F0))
def(PR_POW,             hex(C0))
def(PR_MUL,             hex(A0))
def(PR_ADD,             hex(80))
def(PR_RELATIONAL,      hex(60))
def(PR_LOGICAL,         hex(40))
def(PR_CLOSE_PAREN,     hex(20))
def(PR_OPEN_PAREN,      hex(00))

comment Program states and error codes

def(PS_READY,                       hex(00))
def(PS_STOPPED,                     hex(01))
def(ERR_INTERNAL_ERROR,             hex(02))
def(ERR_OUT_OF_MEMORY,              hex(03))
def(ERR_TYPE_MISMATCH,              hex(04))
def(ERR_CONT_WITHOUT_STOP,          hex(05))
def(ERR_OUT_OF_DATA,                hex(06))
def(ERR_STACK_OVERFLOW,             hex(07))
def(ERR_STACK_EMPTY,                hex(08))
def(ERR_RETURN_WITHOUT_GOSUB,       hex(09))
def(ERR_NEXT_WITHOUT_FOR,           hex(0A))
def(ERR_LINE_NOT_FOUND,             hex(0B))
def(ERR_OUT_OF_RANGE,               hex(0C))
def(ERR_INVALID_VARIABLE,           hex(0D))
def(ERR_ALREADY_DIMENSIONED,        hex(0E))
def(ERR_LINE_TOO_LONG,              hex(0F))
def(ERR_EXPRESSION_TOO_COMPLEX,     hex(10))
def(ERR_FORMAT_ERROR,               hex(11))
def(ERR_DIVIDE_BY_ZERO,             hex(12))
def(ERR_ARITY_MISMATCH,             hex(13))
def(ERR_SYNTAX_ERROR,               hex(14))
def(ERR_IMMEDIATE_MODE_STOP,        hex(15))
def(PS_RUNNING,                     hex(80))

comment Parse virtual machine (PVM) constants and instruction codes

def(PVM_FAIL,                       hex(00))
def(PVM_RETURN,                     hex(01))
def(PVM_WS,                         hex(02))
def(PVM_MATCH_RANGE,                hex(03))
def(PVM_MATCH_ANY,                  hex(04))
def(PVM_COMPOSE,                    hex(05))
def(PVM_ARGSEP,                     hex(06))
def(PVM_TOKENIZE,                   hex(07))


def(PVM_MATCH,                      hex(20))
def(PVM_CALL,                       hex(60))
def(PVM_JUMP,                       hex(70))
def(PVM_TRY,                        hex(80))
def(PVM_ACCEPT,                     hex(C0))





def(PVM_BEGIN,                      hex(64))
def(PVM_DISPATCH,                   hex(66))
def(PVM_EMIT,                       hex(67))
def(PVM_INT,                        hex(69))
def(PVM_EOL,                        hex(6A))
def(PVM_LINK,                       hex(6D))
def(PVM_DISCARD,                    hex(6E))

comment Other constants

def(EOT, hex(80))
def(BUFFER_SIZE, 256)
def(PATTERN_OK, hex(80))
def(PATTERN_ERROR, hex(81))
def(PRIMARY_STACK_SIZE, 192)
def(OP_STACK_SIZE, 16)
def(STRING_EXTRA, 3)

comment Maximum line length we're willing to encode (leave 16 bytes at end for END statement in immediate mode
def(MAX_LINE_LENGTH, 240)
