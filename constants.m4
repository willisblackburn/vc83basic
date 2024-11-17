ifdef(`__C__',
    `define(`def', ``#define $1 $2'') define(`hex', `0x$1') define(`comment', `//')',
    `define(`def', ``$1 = $2'') define(`hex', `$$1') define(`comment', `;')')

comment Generated from __file__

comment Name table definitions 

def(NT_VAR,             hex(10))
def(NT_RPT_VAR,         hex(11))
def(NT_NUM,             hex(12))
def(NT_RPT_NUM,         hex(13))
def(NT_STATEMENT,       hex(14))
def(NT_PEXP,            hex(15))
def(NT_STOP,            hex(80))

comment Tokenized form constants

def(TOKEN_UNARY_OP,     hex(08)) comment OR with OP_UNARY_*
def(TOKEN_OP,           hex(10)) comment OR with OP_*

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
def(ST_ON_GOTO,        10)
def(ST_ON_GOSUB,       11)
def(ST_FOR,            12)
def(ST_NEXT,           13)
def(ST_STOP,           14)
def(ST_CONT,           15)
def(ST_IF_THEN,        16)
def(ST_NEW,            17)
def(ST_CLR,            18)

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

comment Expression decode handlers

def(XH_UNARY_OP,        0)
def(XH_OP,              1)
def(XH_NUM,             2)
def(XH_STRING,          3)
def(XH_VAR,             4)
def(XH_PAREN,           5)

comment Types

def(TYPE_NUM,           hex(00))
def(TYPE_STRING,        hex(01))

comment Expression precedence levels

def(PR_UNARY_OP,        hex(F0))
def(PR_POW,             hex(C0))
def(PR_MUL,             hex(A0))
def(PR_ADD,             hex(80))
def(PR_RELATIONAL,      hex(60))
def(PR_LOGICAL,         hex(40))
def(PR_CLOSE_PAREN,     hex(20))
def(PR_OPEN_PAREN,      hex(00))

comment Program states

def(PS_STOPPED,         hex(00))
def(PS_RUNNING,         hex(01))

comment Other constants

def(BUFFER_SIZE, 256)
def(PATTERN_OK, hex(80))
def(PATTERN_ERROR, hex(81))
def(PRIMARY_STACK_SIZE, 192)
def(OP_STACK_SIZE, 16)
def(STRING_EXTRA, 3)
