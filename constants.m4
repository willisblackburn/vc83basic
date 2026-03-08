dnl SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
dnl
dnl SPDX-License-Identifier: MIT

ifdef(`__C__',
    `define(`def', ``#define $1 $2'') define(`hex', `0x$1') define(`comment', `//')',
    `define(`def', ``$1 = $2'') define(`hex', `$$1') define(`comment', `;')')

comment Generated from __file__

comment Tokenized form constants

def(TOKEN_FUNCTION,     hex(01)) comment Function sentinel
def(TOKEN_UNARY_OP,     hex(04)) comment OR with OP_UNARY_*
def(TOKEN_CLAUSE,       hex(08)) comment OR with CLAUSE_*
def(TOKEN_OP,           hex(10)) comment OR with OP_*
def(TOKEN_EXTENSION,    hex(80)) comment OR with index of extension statement

comment Statement tokens

def(ST_LET,             0)
def(ST_IMPL_LET,        1)
def(ST_RUN,             2)
def(ST_PRINT,           3)
def(ST_ALT_PRINT,       4)
def(ST_LIST,            5)
def(ST_GOTO,            6)
def(ST_IMPL_GOTO,       7)
def(ST_GOSUB,           8)
def(ST_RETURN,          9)
def(ST_POP,            10)
def(ST_ON,             11)
def(ST_FOR,            12)
def(ST_NEXT,           13)
def(ST_STOP,           14)
def(ST_CONT,           15)
def(ST_NEW,            16)
def(ST_CLR,            17)
def(ST_DIM,            18)
def(ST_REM,            19)
def(ST_DATA,           20)
def(ST_READ,           21)
def(ST_RESTORE,        22)
def(ST_POKE,           23)
def(ST_END,            24)
def(ST_INPUT,          25)
def(ST_IF_THEN,        26)

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

comment Non-statement extras

def(CLAUSE_THEN,        0)
def(CLAUSE_GOTO,        1)
def(CLAUSE_GOSUB,       2)
def(CLAUSE_TO,          3)
def(CLAUSE_STEP,        4)

comment Types

def(TYPE_NUMBER,        hex(00))
def(TYPE_STRING,        hex(01))
def(TYPE_CONTROL,       hex(FF)) comment Only used on stack

comment Expression precedence levels

def(PR_UNARY_OP,        hex(F0))
def(PR_POW,             hex(C0))
def(PR_MUL,             hex(A0))
def(PR_ADD,             hex(80))
def(PR_RELATIONAL,      hex(60))
def(PR_LOGICAL,         hex(40))
def(PR_CLOSE_PAREN,     hex(20))
def(PR_OPEN_PAREN,      hex(00))

comment Program states and error codes

def(PS_RUNNING,                     hex(00))
def(PS_READY,                       hex(01))

def(ERR_STOPPED,                    hex(80))
def(ERR_INTERNAL_ERROR,             hex(81))
def(ERR_OUT_OF_MEMORY,              hex(82))
def(ERR_TYPE_MISMATCH,              hex(83))
def(ERR_CONT_WITHOUT_STOP,          hex(84))
def(ERR_OUT_OF_DATA,                hex(85))
def(ERR_STACK_OVERFLOW,             hex(86))
def(ERR_STACK_EMPTY,                hex(87))
def(ERR_RETURN_WITHOUT_GOSUB,       hex(88))
def(ERR_NEXT_WITHOUT_FOR,           hex(89))
def(ERR_LINE_NOT_FOUND,             hex(8A))
def(ERR_OUT_OF_RANGE,               hex(8B))
def(ERR_INVALID_VARIABLE,           hex(8C))
def(ERR_ALREADY_DIMENSIONED,        hex(8D))
def(ERR_LINE_TOO_LONG,              hex(8E))
def(ERR_EXPRESSION_TOO_COMPLEX,     hex(8F))
def(ERR_FORMAT_ERROR,               hex(90))
def(ERR_ARITY_MISMATCH,             hex(91))
def(ERR_SYNTAX_ERROR,               hex(92))
def(ERR_IMMEDIATE_MODE_STOP,        hex(93))
def(ERR_DIVIDE_BY_ZERO,             hex(94))

comment Parse virtual machine (PVM) constants and instruction codes

def(PVM_FAIL,                       hex(00))
def(PVM_RETURN,                     hex(01))
def(PVM_WS,                         hex(02))
def(PVM_MATCH_RANGE,                hex(03))
def(PVM_MATCH_ANY,                  hex(04))
def(PVM_COMPOSE,                    hex(05))
def(PVM_ARGSEP,                     hex(06))
def(PVM_DISPATCH,                   hex(07))
def(PVM_EMIT,                       hex(08))
def(PVM_TOKENIZE,                   hex(10))
def(PVM_MATCH,                      hex(20))
def(PVM_CALL,                       hex(60))
def(PVM_JUMP,                       hex(70))
def(PVM_TRY,                        hex(80))
def(PVM_ACCEPT,                     hex(C0))

comment Other constants

def(EOT, hex(80))
def(BUFFER_SIZE, 256)
def(PATTERN_OK, hex(80))
def(PATTERN_ERROR, hex(81))
def(PRIMARY_STACK_SIZE, 192)
def(OP_STACK_SIZE, 16)
def(STRING_EXTRA, 3)

comment Maximum line length we're willing to encode (leave 16 bytes at end for END statement in immediate mode
def(MAX_LINE_LENGTH, 240)
