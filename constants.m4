ifdef(`__C__',
    `define(`def', ``#define $1 $2'') define(`hex', `0x$1') define(`comment', `//')',
    `define(`def', ``$1 = $2'') define(`hex', `$$1') define(`comment', `;')')

comment Generated from __file__

comment Name table definitions 

def(NT_VAR,             hex(10))
def(NT_RPT_VAR,         hex(11))
def(NT_END,             hex(80))

comment Tokenized form constants

def(TOKEN_NO_VALUE,     hex(00))
def(TOKEN_PAREN,        hex(01))
def(TOKEN_UNARY_OP,     hex(08)) comment OR with OP_UNARY_*
def(TOKEN_OP,           hex(10)) comment OR with OP_*
def(TOKEN_NUM,          hex(20))
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

comment Binary operator tokens: combine with TOKEN_UNARY_OP

def(UNARY_OP_MINUS,     0)
def(UNARY_OP_NOT,       1)

comment Expression decode handlers

def(XH_VAR,             0)
def(XH_NUM,             1)
def(XH_OP,              2)
def(XH_UNARY_OP,        3)
def(XH_PAREN,           4)

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

def(PROGRAM_STATE_STOPPED,      hex(00))
def(PROGRAM_STATE_RUNNING,      hex(01))

comment Other constants

def(OP_STACK_DEPTH, 16)
def(VALUE_STACK_DEPTH, 16)
