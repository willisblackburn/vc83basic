
function_arity_table:
        .byte   1   ; LEN
        .byte   1   ; STR$
        .byte   1   ; CHR$
        .byte   1   ; ASC
        .byte   2   ; LEFT$
        .byte   2   ; RIGHT$
        .byte   3   ; MID$
        .byte   1   ; VAL
        .byte   0   ; FRE
        .byte   1   ; PEEK
        .byte   1   ; ADR
        .byte   2   ; USR
        .byte   1   ; INT
        .byte   1   ; ROUND
        .byte   1   ; LOG
        .byte   1   ; EXP
        .byte   1   ; SIN
        .byte   1   ; COS
        .byte   1   ; TAN
        .byte   1   ; ABS
        .byte   1   ; SGN
        .byte   1   ; SQR

; Operator precedence table
; We index this by the operator index divided by 2.

operator_precedence_table:
        .byte   PR_ADD                  ; +, -
        .byte   PR_MUL                  ; *, /
        .byte   PR_POW                  ; ^, &
        .byte   PR_RELATIONAL           ; =, <>
        .byte   PR_RELATIONAL           ; <=, <
        .byte   PR_RELATIONAL           ; >=, >
        .byte   PR_LOGICAL              ; AND, OR

type_size_table:
        .byte .sizeof(Float)            ; TYPE_NUMBER
        .byte 2                         ; TYPE_STRING

error_message_table:
        .byte :+ - *, "STOPPED"
:       .byte :+ - *, "INTERNAL ERROR"
:       .byte :+ - *, "OUT OF MEMORY"
:       .byte :+ - *, "TYPE MISMATCH"
:       .byte :+ - *, "CONT WITHOUT STOP"
:       .byte :+ - *, "OUT OF DATA"
:       .byte :+ - *, "STACK OVERFLOW"
:       .byte :+ - *, "STACK EMPTY"
:       .byte :+ - *, "RETURN WITHOUT GOSUB"
:       .byte :+ - *, "NEXT WITHOUT FOR"
:       .byte :+ - *, "LINE NOT FOUND"
:       .byte :+ - *, "OUT OF RANGE"
:       .byte :+ - *, "INVALID VARIABLE"
:       .byte :+ - *, "ALREADY DIMENSIONED"
:       .byte :+ - *, "LINE TOO LONG"
:       .byte :+ - *, "EXPRESSION TOO COMPLEX"
:       .byte :+ - *, "FORMAT ERROR"
:       .byte :+ - *, "ARITY MISMATCH"
:       .byte :+ - *, "SYNTAX ERROR"
:       .byte :+ - *, "IMMEDIATE MODE STOP"
:       .byte :+ - *, "DIVIDE BY ZERO"
:       .byte 0