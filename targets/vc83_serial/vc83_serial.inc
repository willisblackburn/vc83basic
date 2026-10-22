; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

; Hardware Bank Select Registers
BANK_SELECT_A   := $00
BANK_SELECT_D   := $03

; Bus Accelerator Registers ($04-$1F)
DST_DATA            := $04
DST_DATA_INC        := $05
DST_ADDR            := $06
DST_STEP            := $09
DST_FRAC            := $0B
SRC_DATA            := $0C
SRC_DATA_INC        := $0D
SRC_ADDR            := $0E
DST_LINE_ERROR      := $0E
SRC_STEP            := $11
DST_LINE_DIAG_STEP  := $11
SRC_FRAC            := $13
DST_LINE_DIAG_FRAC  := $13
DST_MASK            := $14
COPY_SRC_DST        := $15
MODE                := $16
MUL_A               := $18
MUL_B               := $1A
MUL_C               := $1C
MUL_RESULT          := $1C
MUL_TO_DST          := $1F

MODE_8BPP           = $00
MODE_4BPP           = $01
MODE_2BPP           = $02
MODE_1BPP           = $03
MODE_LINE_BIT       = $04


; OS API Vectors and Registers
API_EXEC        := $E000
API_VCGALAYER   := $E003
API_OPEN        := $E006
API_CLOSE       := $E009
API_GET         := $E00C
API_PUT         := $E00F
API_READ        := $E012
API_WRITE       := $E015
API_STATUS      := $E018
API_XIO         := $E01B
API_READLINE    := $E02A
API_SPIXFER     := $E02D
API_I2CXFER     := $E030
API_SETIRQ      := $E033

WARM_START_VECTOR   := $0350

KEYBOARD_OPTIONS    := $D084
KEYBOARD_STATUS     := $D085
IRQ_KEYBOARD        = 6

OPEN_READ       = 0
OPEN_WRITE      = 1
OPEN_READ_WRITE = 2
OPEN_APPEND     = 3
OPEN_DIRECTORY  = 4
OPEN_RAW        = 16
OPEN_ACCESS_MASK = $03

ERR_EOF         = $08
ERR_BREAK       = $0C

XIO_COLOR       = $20
XIO_MOVE        = $21
XIO_PLOT        = $22
XIO_DRAWTO      = $23
XIO_FILLTO      = $24
XIO_LOCATE      = $25

; I/O Port Capability and Register Offsets (Window D mapped to $E0)
CAP_SPI             = $01
CAP_I2C             = $02
CAP_GPIO            = $08
CAP_PWM             = $10
CAP_ANALOG          = $20
CAP_RESET           = $40

IO_GPIO_OUT_0       = $10
IO_GPIO_IN_0        = $11
IO_GPIO_DIR_0       = $12
IO_GPIO_OUT_1       = $18
IO_GPIO_IN_1        = $19
IO_GPIO_DIR_1       = $1A

IO_SPI_CTRL         = $20
IO_SPI_CLK_DIV      = $22
IO_SPI_CS_SELECT    = $23

IO_I2C_CTRL         = $30
IO_I2C_CLK_DIV      = $32
IO_I2C_ADDR         = $33

IO_PWM_CTRL         = $50
IO_PWM_PRESCALER    = $51
IO_PWM_PERIOD_LO    = $52
IO_PWM_PERIOD_HI    = $53
IO_PWM_DUTY_LO      = $54
IO_PWM_DUTY_HI      = $55

IO_ADC_CTRL         = $60
IO_ADC_DATA_LO      = $62
IO_ADC_DATA_HI      = $63

IO_RESET_CTRL       = $70
IO_RESET_PULSE_LEN  = $71

SPI_WRITE_ONLY      = $80
SPI_CS_HOLD         = $04

I2C_READ            = $80
I2C_NO_STOP         = $40
I2C_NO_START        = $20

arg1            := $20
arg2            := $21
arg3            := $22
arg4            := $23
arg5            := $26
break_flag      := $27
path_ptr        := $31
path_len        := $33
io_ptr          := $34
io_seg          := $36
io_len          := $37

TOK_OPEN        = $60
TOK_CLOSE       = $61
TOK_XIO         = $62
TOK_DIR         = $63
TOK_STATUS      = $64
TOK_GRMODE      = $65
TOK_COLOR       = $66
TOK_PLOT        = $67
TOK_DRAWTO      = $68
TOK_FILLTO      = $69
TOK_MOVE        = $6A
TOK_SETCOLOR    = $6B
TOK_SOURCE      = $6C
TOK_SYNC        = $6D
TOK_POKE24      = $6E
TOK_DPOKE24     = $6F
TOK_SPIWRITE    = $70
TOK_I2CWRITE    = $71
TOK_PORTDIR     = $72
TOK_SPICLOSE    = $73
TOK_I2CCLOSE    = $74
TOK_EXEC        = $75
TOK_PORTWRITE   = $76
TOK_I2COPEN     = $77
TOK_SPIOPEN     = $78
TOK_PORTRESET   = $79
TOK_PORTPWM     = $7A
TOK_NOTE        = $7B
TOK_PROGRAM     = $7C
TOK_CONTROL     = $7D

TOK_LOCATE      = $9A
TOK_STRING_S    = $9B
TOK_PEEK24      = $9C
TOK_DPEEK24     = $9D
TOK_SPACE_S     = $9E
TOK_PORT        = $9F
TOK_PORTADC     = $A0
TOK_SPI_S       = $A1
TOK_I2C_S       = $A2
TOK_BUF_S       = $A3

.macro extension_check_break
        bit     break_flag              ; Check if break was requested
        bpl     :+
        jmp     on_break
:
.endmacro

.macro extension_statement_keywords
:       name_table_entry "OPEN"
:       name_table_entry "CLOSE"
:       name_table_entry "XIO"
:       name_table_entry "DIR"
:       name_table_entry "STATUS"
:       name_table_entry "GRMODE"
:       name_table_entry "COLOR"
:       name_table_entry "PLOT"
:       name_table_entry "DRAWTO"
:       name_table_entry "FILLTO"
:       name_table_entry "MOVE"
:       name_table_entry "SETCOLOR"
:       name_table_entry "SOURCE"
:       name_table_entry "SYNC"
:       name_table_entry "POKE24"
:       name_table_entry "DPOKE24"
KEYWORD_BLOCK_7_OFFSET = keyword_counter
:       name_table_entry "SPIWRITE"
:       name_table_entry "I2CWRITE"
:       name_table_entry "PORTDIR"
:       name_table_entry "SPICLOSE"
:       name_table_entry "I2CCLOSE"
:       name_table_entry "EXEC"
:       name_table_entry "PORTWRITE"
:       name_table_entry "I2COPEN"
:       name_table_entry "SPIOPEN"
:       name_table_entry "PORTRESET"
:       name_table_entry "PORTPWM"
:       name_table_entry "NOTE"
:       name_table_entry "PROGRAM"
:       name_table_entry "CONTROL"
.endmacro

.macro extension_statement_vectors_l
        .byte   <(exec_open-1)
        .byte   <(exec_close-1)
        .byte   <(exec_xio-1)
        .byte   <(exec_dir-1)
        .byte   <(exec_status-1)
        .byte   <(exec_grmode-1)
        .byte   <(exec_color-1)
        .byte   <(exec_plot-1)
        .byte   <(exec_drawto-1)
        .byte   <(exec_fillto-1)
        .byte   <(exec_move-1)
        .byte   <(exec_setcolor-1)
        .byte   <(exec_source-1)
        .byte   <(exec_sync-1)
        .byte   <(exec_poke24-1)
        .byte   <(exec_dpoke24-1)
        .byte   <(exec_spiwrite-1)
        .byte   <(exec_i2cwrite-1)
        .byte   <(exec_portdir-1)
        .byte   <(exec_spiclose-1)
        .byte   <(exec_i2cclose-1)
        .byte   <(exec_exec-1)
        .byte   <(exec_portwrite-1)
        .byte   <(exec_i2copen-1)
        .byte   <(exec_spiopen-1)
        .byte   <(exec_portreset-1)
        .byte   <(exec_portpwm-1)
        .byte   <(exec_note-1)
        .byte   <(exec_program-1)
        .byte   <(exec_control-1)
.endmacro

.macro extension_statement_vectors_h
        .byte   >(exec_open-1)
        .byte   >(exec_close-1)
        .byte   >(exec_xio-1)
        .byte   >(exec_dir-1)
        .byte   >(exec_status-1)
        .byte   >(exec_grmode-1)
        .byte   >(exec_color-1)
        .byte   >(exec_plot-1)
        .byte   >(exec_drawto-1)
        .byte   >(exec_fillto-1)
        .byte   >(exec_move-1)
        .byte   >(exec_setcolor-1)
        .byte   >(exec_source-1)
        .byte   >(exec_sync-1)
        .byte   >(exec_poke24-1)
        .byte   >(exec_dpoke24-1)
        .byte   >(exec_spiwrite-1)
        .byte   >(exec_i2cwrite-1)
        .byte   >(exec_portdir-1)
        .byte   >(exec_spiclose-1)
        .byte   >(exec_i2cclose-1)
        .byte   >(exec_exec-1)
        .byte   >(exec_portwrite-1)
        .byte   >(exec_i2copen-1)
        .byte   >(exec_spiopen-1)
        .byte   >(exec_portreset-1)
        .byte   >(exec_portpwm-1)
        .byte   >(exec_note-1)
        .byte   >(exec_program-1)
        .byte   >(exec_control-1)
.endmacro

.macro extension_statement_flags
        .byte   0                                               ; OPEN, CLOSE
        .byte   0                                               ; XIO, DIR
        .byte   PROLOG_NONE | (PROLOG_POP_INT << 4)             ; STATUS, GRMODE
        .byte   PROLOG_POP_INT | (PROLOG_POP_INT << 4)          ; COLOR, PLOT
        .byte   PROLOG_POP_INT | (PROLOG_POP_INT << 4)          ; DRAWTO, FILLTO
        .byte   PROLOG_POP_INT | (PROLOG_POP_INT << 4)          ; MOVE, SETCOLOR
        .byte   PROLOG_POP_STRING | (PROLOG_POP_INT << 4)       ; SOURCE, SYNC
        .byte   PROLOG_POP_INT | (PROLOG_POP_INT << 4)          ; POKE24, DPOKE24
        .byte   PROLOG_POP_STRING | (PROLOG_POP_STRING << 4)    ; SPIWRITE, I2CWRITE
        .byte   PROLOG_POP_INT | (PROLOG_POP_INT << 4)          ; PORTDIR, SPICLOSE
        .byte   PROLOG_POP_INT | (PROLOG_POP_STRING << 4)       ; I2CCLOSE, EXEC
        .byte   0                                               ; PORTWRITE, I2COPEN
        .byte   0                                               ; SPIOPEN, PORTRESET
        .byte   0                                               ; PORTPWM, NOTE
        .byte   0                                               ; PROGRAM, CONTROL
.endmacro

.macro extension_pvm_statements
        BRANCH_IF TOK_OPEN, pvm_open
        BRANCH_IF TOK_CLOSE, pvm_close
        BRANCH_IF TOK_XIO, pvm_xio
        BRANCH_IF TOK_DIR, pvm_dir
        BRANCH_IF TOK_STATUS, pvm_get
        BRANCH_IF TOK_GRMODE, pvm_expression
        BRANCH_IF TOK_COLOR, pvm_put
        BRANCH_IF_RANGE TOK_PLOT, 4, pvm_plot
        BRANCH_IF TOK_SETCOLOR, pvm_setcolor
        BRANCH_IF TOK_SOURCE, pvm_expression
        BRANCH_IF TOK_SYNC, pvm_expression
        BRANCH_IF_RANGE TOK_POKE24, 5, pvm_arg_2
        BRANCH_IF_RANGE TOK_SPICLOSE, 3, pvm_expression
        BRANCH_IF_RANGE TOK_PORTWRITE, 2, pvm_i2copen
        BRANCH_IF TOK_SPIOPEN, pvm_spiopen
        BRANCH_IF TOK_PORTRESET, pvm_1_to_3_args
        BRANCH_IF TOK_PORTPWM, pvm_portpwm
        BRANCH_IF TOK_NOTE, pvm_note
        BRANCH_IF TOK_PROGRAM, pvm_plot
        BRANCH_IF TOK_CONTROL, pvm_control
.endmacro

.macro extension_pvm_code
pvm_dir:
        GUARD   TOK_COLON
        GUARD   TOK_EOL
        JUMP    pvm_expression

pvm_open:
        CALL    pvm_channel
        JUMP    pvm_1_to_2_args

pvm_close:
        CALL    pvm_channel
        RETURN

pvm_xio:
        CALL    pvm_channel
        JUMP    pvm_1_to_3_args

pvm_plot:
        CALL    pvm_channel
        JUMP    pvm_arg_2

pvm_note:
        CALL    pvm_channel
        JUMP    pvm_i2copen

pvm_control:
        CALL    pvm_channel
        JUMP    pvm_arg_3

pvm_locate:
        MATCH   TOK_LPAREN
        CALL    pvm_channel
        CALL    pvm_arg_2
        JUMP    pvm_close_paren

pvm_portpwm:
        CALL    pvm_expression
        BRANCH_IF TOK_COMMA, pvm_portpwm_enable
        RETURN

pvm_portpwm_enable:
        CALL    pvm_arg_2
        MATCH   TOK_COMMA
        JUMP    pvm_1_to_3_args

pvm_spiopen:
        CALL    pvm_expression
        MATCH   TOK_COMMA
pvm_1_to_3_args:
        CALL    pvm_expression
        BRANCH_IF TOK_COMMA, pvm_1_to_2_args
        RETURN

pvm_i2copen:
        CALL    pvm_expression
        MATCH   TOK_COMMA
pvm_1_to_2_args:
        CALL    pvm_expression
        BRANCH_IF TOK_COMMA, pvm_expression
        RETURN

pvm_setcolor:
        CALL    pvm_expression
        MATCH   TOK_COMMA
        CALL    pvm_expression
        MATCH   TOK_COMMA
        CALL    pvm_expression
        MATCH   TOK_COMMA
        CALL    pvm_expression
        MATCH   TOK_COMMA
        JUMP    pvm_expression

pvm_spi_fun:
        MATCH   TOK_LPAREN
        CALL    pvm_arg_2
        BRANCH_IF TOK_COMMA, pvm_subexpression
        JUMP    pvm_close_paren

pvm_buf_fun:
        MATCH   TOK_LPAREN
        CALL    pvm_arg_list
        JUMP    pvm_close_paren
.endmacro

.macro extension_function_keywords
:       name_table_entry "LOCATE"
:       name_table_entry "STRING$"
:       name_table_entry "PEEK24"
:       name_table_entry "DPEEK24"
:       name_table_entry "SPACE$"
:       name_table_entry "PORT"
KEYWORD_BLOCK_A_OFFSET = keyword_counter
:       name_table_entry "PORTADC"
:       name_table_entry "SPI$"
:       name_table_entry "I2C$"
:       name_table_entry "BUF$"
.endmacro

.macro extension_pvm_functions
        BRANCH_IF TOK_LOCATE, pvm_locate
        BRANCH_IF TOK_STRING_S, pvm_fun_2
        BRANCH_IF_RANGE TOK_PEEK24, 5, pvm_fun_1
        BRANCH_IF_RANGE TOK_SPI_S, 2, pvm_spi_fun
        BRANCH_IF TOK_BUF_S, pvm_buf_fun
.endmacro

.macro extension_function_vectors_l
        .byte   <(fun_locate-1)
        .byte   <(fun_string_s-1)
        .byte   <(fun_peek24-1)
        .byte   <(fun_dpeek24-1)
        .byte   <(fun_space_s-1)
        .byte   <(fun_port-1)
        .byte   <(fun_portadc-1)
        .byte   <(fun_spi_s-1)
        .byte   <(fun_i2c_s-1)
        .byte   <(fun_buf_s-1)
.endmacro

.macro extension_function_vectors_h
        .byte   >(fun_locate-1)
        .byte   >(fun_string_s-1)
        .byte   >(fun_peek24-1)
        .byte   >(fun_dpeek24-1)
        .byte   >(fun_space_s-1)
        .byte   >(fun_port-1)
        .byte   >(fun_portadc-1)
        .byte   >(fun_spi_s-1)
        .byte   >(fun_i2c_s-1)
        .byte   >(fun_buf_s-1)
.endmacro

.macro extension_function_flags
        .byte   (PROLOG_NONE | EPILOG_PUSH_INT) | ((PROLOG_POP_INT | EPILOG_PUSH_STRING) << 4)          ; LOCATE, STRING$
        .byte   (PROLOG_POP_FP | EPILOG_PUSH_INT) | ((PROLOG_POP_FP | EPILOG_PUSH_INT) << 4)            ; PEEK24, DPEEK24
        .byte   (PROLOG_POP_INT | EPILOG_PUSH_STRING) | ((PROLOG_POP_INT | EPILOG_PUSH_INT) << 4)       ; SPACE$, PORT
        .byte   (PROLOG_POP_INT | EPILOG_PUSH_INT) | ((PROLOG_NONE | EPILOG_PUSH_STRING) << 4)          ; PORTADC, SPI$
        .byte   (PROLOG_NONE | EPILOG_PUSH_STRING) | ((PROLOG_NONE | EPILOG_PUSH_STRING) << 4)          ; I2C$, BUF$
.endmacro
