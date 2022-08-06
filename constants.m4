ifdef(`__C__',
    `define(`def', `#define $1 $2') define(`hex', `0x$1') define(`comment', `//')',
    `define(`def', `$1 = $2') define(`hex', `$$1') define(`comment', `;')')

comment Generated from __file__

def(TYPE_NONE,          hex(00))
def(TYPE_INT,           hex(01))
def(TYPE_FLOAT,         hex(02))
def(TYPE_STRING,        hex(04))
def(TYPE_ANY,           hex(07))
def(TYPE_VAR,           hex(08))
def(TYPE_CH,            hex(09))
def(TYPE_PROMPT,        hex(0A))
def(TYPE_PRINT,         hex(0B))
def(TYPE_THEN,          hex(0C))
def(TYPE_STEP,          hex(0D))
def(TYPE_TEXT,          hex(0E))
def(TYPE_END,           hex(80))

comment Name table definitions 

def(NT_OPTIONAL,        hex(08))
def(NT_EXPRESSION,      hex(10))
def(NT_NUMBER,          hex(11))
def(NT_VAR,             hex(12))
def(NT_DATA,            hex(13))
def(NT_CHANNEL,         hex(14))
def(NT_PROMPT,          hex(15))
def(NT_PRINT,           hex(16))
def(NT_THEN,            hex(17))
def(NT_STEP,            hex(18))
def(NT_TEXT,            hex(19))
def(NT_DIM,             hex(1A))
def(NT_RPT_EXPRESSION,  hex(1C))
def(NT_RPT_NUMBER,      hex(1D))
def(NT_RPT_VAR,         hex(1E))
def(NT_RPT_DATA,        hex(1F))
def(NT_END,             hex(80))

comment Tokenized form constants

def(TOKEN_END_REPEAT,   hex(00))
def(TOKEN_NO_VALUE,     hex(01))
def(TOKEN_INT,          hex(02))
def(TOKEN_FLOAT,        hex(03))
def(TOKEN_STRING,       hex(04))

comment Statements
comment Must match statement_name_table.

def(ST_RUN,             0)
def(ST_PRINT,           1)
def(ST_LET,             2)
def(ST_INPUT,           3)

comment Status and error codes

def(STATUS_OK,          hex(00))
def(ERR_FAIL,           hex(FF))
