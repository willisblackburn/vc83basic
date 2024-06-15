ifdef(`__C__',
    `define(`def', ``#define $1 $2'') define(`hex', `0x$1') define(`comment', `//')',
    `define(`def', ``$1 = $2'') define(`hex', `$$1') define(`comment', `;')')

comment Generated from __file__

comment Name table definitions 

def(NT_VAR,             hex(10))
def(NT_STOP,            hex(80))

comment Tokenized form constants

def(TOKEN_NUM,          hex(01))
def(TOKEN_VAR,          hex(20)) comment OR with variable length

comment Statement tokens

def(ST_RUN,             0)
def(ST_PRINT,           1)
def(ST_LET,             2)

comment Other constants

def(BUFFER_SIZE, 256)
