ifdef(`__C__',
    `define(`def', ``#define $1 $2'') define(`hex', `0x$1') define(`comment', `//')',
    `define(`def', ``$1 = $2'') define(`hex', `$$1') define(`comment', `;')')

comment Generated from __file__

comment Name table definitions 

def(NT_OPTIONAL,        hex(08))
def(NT_EXPRESSION,      hex(10))
def(NT_NUMBER,          hex(11))
def(NT_VAR,             hex(12))
def(NT_RPT_EXPRESSION,  hex(1C))
def(NT_RPT_NUMBER,      hex(1D))
def(NT_RPT_VAR,         hex(1E))
def(NT_END,             hex(80))

comment Tokenized form constants

def(TOKEN_NO_VALUE,     hex(00))
def(TOKEN_INT,          hex(01))
def(TOKEN_LPAREN,       hex(06))
def(TOKEN_RPAREN,       hex(07))
def(TOKEN_NOT,          hex(08))
def(TOKEN_MINUS,        hex(09))
def(TOKEN_COMMA,        hex(0A))
def(TOKEN_SEMI,         hex(0B))
def(TOKEN_OP,           hex(10)) comment OR with OP_*
def(TOKEN_VAR,          hex(80)) comment OR with variable number

comment Statement tokens

def(ST_RUN,             0)
def(ST_PRINT,           1)
def(ST_LET,             2)
def(ST_INPUT,           3)
def(ST_LIST,            4)

comment Binary operator tokens: combine with TOKEN_OP

def(OP_ADD,             0)
def(OP_SUB,             1)
def(OP_MUL,             2)
def(OP_DIV,             3)
def(OP_POW,             4)
def(OP_CONCAT,          5)
def(OP_EQ,              6)
def(OP_NE,              7)
def(OP_LE,              8)
def(OP_LT,              9)
def(OP_GE,             10)
def(OP_GT,             11)
def(OP_AND,            12)
def(OP_OR,             13)

comment Program states

def(PROGRAM_STATE_NOT_RUNNING,  hex(00))    comment Variables initalized to 0
def(PROGRAM_STATE_RUNNING,      hex(01))    comment STOP command stops program; END resets
def(PROGRAM_STATE_STOPPED,      hex(02))    comment CONT command continues; CLR resets
