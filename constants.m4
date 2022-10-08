ifdef(`__C__',
    `define(`def', ``#define $1 $2'') define(`hex', `0x$1') define(`comment', `//')',
    `define(`def', ``$1 = $2'') define(`hex', `$$1') define(`comment', `;')')

comment Generated from __file__

comment Name table definitions 

def(NT_EXP,             hex(10))
def(NT_NUM,             hex(11))
def(NT_VAR,             hex(12))
def(NT_RPT_EXP,         hex(1C))
def(NT_RPT_NUM,         hex(1D))
def(NT_RPT_VAR,         hex(1E))
def(NT_END,             hex(80))

comment Tokenized form constants

def(TOKEN_NO_VALUE,     hex(00))
def(TOKEN_NUM,          hex(01))
def(TOKEN_VAR,          hex(80)) comment OR with variable number

comment Statement tokens

def(ST_RUN,             0)
def(ST_PRINT,           1)
def(ST_LET,             2)
def(ST_INPUT,           3)
