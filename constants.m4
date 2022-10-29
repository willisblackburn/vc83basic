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
def(TOKEN_NUM,          hex(20))
def(TOKEN_VAR,          hex(80)) comment OR with variable number

comment Statement tokens

def(ST_RUN,             0)
def(ST_PRINT,           1)
def(ST_LET,             2)
def(ST_INPUT,           3)
def(ST_LIST,            4)

comment Program states

def(PROGRAM_STATE_STOPPED,      hex(00))
def(PROGRAM_STATE_RUNNING,      hex(01))
