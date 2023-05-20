  

// Generated from constants.m4

// Name table definitions 

#define NT_VAR 0x10
#define NT_RPT_VAR 0x11
#define NT_NUM 0x12
#define NT_RPT_NUM 0x13
#define NT_STATEMENT 0x14
#define NT_END 0x80

// Tokenized form constants

#define TOKEN_NO_VALUE 0x00
#define TOKEN_PAREN 0x01
#define TOKEN_UNARY_OP 0x08 // OR with OP_UNARY_*
#define TOKEN_OP 0x10 // OR with OP_*
#define TOKEN_NUM 0x20
#define TOKEN_VAR 0x80 // OR with variable number

// Statement tokens

#define ST_END 0
#define ST_RUN 1
#define ST_PRINT 2
#define ST_LET 3
#define ST_INPUT 4
#define ST_LIST 5
#define ST_GOTO 6
#define ST_GOSUB 7
#define ST_RETURN 8
#define ST_POP 9
#define ST_ON_GOTO 10
#define ST_ON_GOSUB 11
#define ST_FOR 12
#define ST_NEXT 13
#define ST_STOP 14
#define ST_CONT 15
#define ST_IF_THEN 16

// Binary operator tokens: combine with TOKEN_OP

#define OP_ADD 0
#define OP_SUB 1
#define OP_MUL 2
#define OP_DIV 3
#define OP_POW 4
#define OP_CONCAT 5
#define OP_EQ 6
#define OP_LT 7
#define OP_GT 8
#define OP_NE 9
#define OP_LE 10
#define OP_GE 11
#define OP_AND 12
#define OP_OR 13

// Binary operator tokens: combine with TOKEN_UNARY_OP

#define UNARY_OP_MINUS 0
#define UNARY_OP_NOT 1

// Expression decode handlers

#define XH_VAR 0
#define XH_NUM 1
#define XH_OP 2
#define XH_UNARY_OP 3
#define XH_PAREN 4

// Expression precedence levels

#define PR_UNARY_OP 0xF0
#define PR_POW 0xC0
#define PR_MUL 0xA0
#define PR_ADD 0x80
#define PR_RELATIONAL 0x60
#define PR_LOGICAL 0x40
#define PR_CLOSE_PAREN 0x20
#define PR_OPEN_PAREN 0x00

// Program states

#define PS_STOPPED 0x00
#define PS_RUNNING 0x01

// Other constants

#define PRIMARY_STACK_SIZE 192
#define OP_STACK_SIZE 16
