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

comment Statement tokens

def(ST_RUN,             0)
def(ST_PRINT,           1)
def(ST_LET,             2)
def(ST_INPUT,           3)

comment Other constants

def(EOT, hex(80))
def(BUFFER_SIZE, 256)
def(PATTERN_OK, hex(80))
def(PATTERN_ERROR, hex(81))
