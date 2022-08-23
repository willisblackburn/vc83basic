ifdef(`__C__',
    `define(`def', ``#define $1 $2'') define(`hex', `0x$1') define(`comment', `//')',
    `define(`def', ``$1 = $2'') define(`hex', `$$1') define(`comment', `;')')

comment Generated from __file__

comment Name table definitions 

def(NT_EXPRESSION,      hex(10))
def(NT_NUMBER,          hex(11))
def(NT_VAR,             hex(12))
def(NT_END,             hex(80))

comment Tokenized form constants

def(TOKEN_INT,          hex(01))
