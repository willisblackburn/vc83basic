  

// Generated from constants.m4

#define TYPE_NONE 0x00
#define TYPE_INT 0x01
#define TYPE_FLOAT 0x02
#define TYPE_STRING 0x04
#define TYPE_ANY 0x07
#define TYPE_VAR 0x08
#define TYPE_CH 0x09
#define TYPE_PROMPT 0x0A
#define TYPE_PRINT 0x0B
#define TYPE_THEN 0x0
#define TYPE_STEP 0x0D
#define TYPE_IGNORE 0x0E

// Type modifiers

#define TYPE_REPEATED 0x20
#define TYPE_REQUIRED 0x40
#define TYPE_END 0x80

#define TYPE_MASK_TYPE_ONLY 0x0F
#define TYPE_MASK_CLEAR_REPEATED 0xDF

// Name table definitions 

#define NT_END 0x80

// Tokenized form constants

#define TOKEN_END_OF_LINE 0x00
#define TOKEN_NO_VALUE 0x01
#define TOKEN_INT 0x02
#define TOKEN_FLOAT 0x03
#define TOKEN_STRING 0x04

// Statements
// Must match statement_name_table.

#define ST_LIST 0
#define ST_RUN 1
#define ST_PRINT 2
#define ST_LET 3
#define ST_INPUT 4
#define ST_DATA 5
#define ST_READ 6
#define ST_RESTORE 7

// Status and error codes

#define STATUS_OK 0x00
#define ERR_FAIL 0xFF
