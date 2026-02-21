dnl SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
dnl
dnl SPDX-License-Identifier: MIT

ifdef(`__C__',
    `define(`def', ``#define $1 $2'') define(`hex', `0x$1') define(`comment', `//')',
    `define(`def', ``$1 = $2'') define(`hex', `$$1') define(`comment', `;')')

comment Generated from __file__

comment Name table definitions 

def(NT_VAR,             hex(10))
def(NT_RPT_VAR,         hex(11))

comment Tokenized form constants

def(TOKEN_UNARY_OP,     hex(08)) comment OR with OP_UNARY_*
def(TOKEN_OP,           hex(10)) comment OR with OP_*

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

comment Binary operator tokens: combine with TOKEN_UNARY_OP

def(UNARY_OP_MINUS,     0)

comment Expression decode handlers

def(XH_UNARY_OP,        0)
def(XH_OP,              1)
def(XH_NUMBER,          2)
def(XH_VAR,             3)
def(XH_PAREN,           4)

comment Expression precedence levels

def(PR_UNARY_OP,        hex(F0))
def(PR_POW,             hex(C0))
def(PR_MUL,             hex(A0))
def(PR_ADD,             hex(80))
def(PR_CLOSE_PAREN,     hex(20))
def(PR_OPEN_PAREN,      hex(00))

comment Program states

def(PS_STOPPED,         hex(00))
def(PS_RUNNING,         hex(01))

comment Other constants

def(EOT, hex(80))
def(BUFFER_SIZE, 256)
def(PATTERN_OK, hex(80))
def(PATTERN_ERROR, hex(81))
def(PRIMARY_STACK_SIZE, 192)
def(OP_STACK_SIZE, 16)
