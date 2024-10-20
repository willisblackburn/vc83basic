ifdef(`__C__',
    `define(`def', ``#define $1 $2'') define(`hex', `0x$1') define(`comment', `//')',
    `define(`def', ``$1 = $2'') define(`hex', `$$1') define(`comment', `;')')

comment Generated from __file__

comment Name table definitions 

def(NT_VAR,             hex(10))
def(NT_RPT_VAR,         hex(11))
def(NT_STOP,            hex(80))

comment Statement tokens

def(ST_RUN,             0)
def(ST_PRINT,           1)
def(ST_LET,             2)
def(ST_INPUT,           3)
def(ST_LIST,            4)

comment Program states

def(PS_STOPPED,         hex(00))
def(PS_RUNNING,         hex(01))

comment Other constants

def(BUFFER_SIZE, 256)
