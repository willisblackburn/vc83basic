ifdef(`C',
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
def(TYPE_IGNORE,        hex(0E))

comment Type modifiers

def(TYPE_REPEATED,      hex(20))
def(TYPE_REQUIRED,      hex(40))
def(TYPE_END,           hex(80))

def(TYPE_MASK_TYPE_ONLY,        hex(0F))
def(TYPE_MASK_CLEAR_REPEATED,   hex(DF))

comment Name table definitions 

def(NT_END,             hex(80))

comment Tokenized form constants

def(TOKEN_END_OF_LINE,  hex(00))
def(TOKEN_NO_VALUE,     hex(01))
def(TOKEN_INT,          hex(02))
def(TOKEN_FLOAT,        hex(03))
def(TOKEN_STRING,       hex(04))

comment Statements
comment Must match statement_name_table.

def(ST_LIST,            0)
def(ST_RUN,             1)
def(ST_PRINT,           2)
def(ST_LET,             3)
def(ST_INPUT,           4)
def(ST_DATA,            5)
def(ST_READ,            6)
def(ST_RESTORE,         7)

comment Status and error codes

def(STATUS_OK,          hex(00))
def(ERR_FAIL,           hex(FF))
