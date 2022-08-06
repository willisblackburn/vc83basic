.include "macros.inc"
.include "basic.inc"

.zeropage

; The line from which we're reading DATA values.
; Set to program_ptr when the program is run.
; If this points to the end of the program (line -1) then we're out of data.
data_line_ptr: .res 2

; The position from which we're reading DATA values.
; If 0 then we need to look for a DATA statement first on this line, or on subsequent lines.
data_r: .res 1

; How many values are left to read in the current DATA statement.
data_count: .res 1

.code 

; READ statement:

; When reading we're in one of several states.
; Seeking: Just after executing RUN or RESTORE, data_r will be 0, meaning we need to look for a DATA
; statement on this or subsequent lines.
; Reading: data_r points to the next value to read, which will either an actual value, or TOKEN_END_REPEAT (0).

exec_read:
        jsr     decode_byte             ; Read the variable
        jsr     set_variable_value_ptr  ; Sets variable_value_ptr to the storage area for the variable
        ldphaa  line_ptr                ; Save line_ptr and r to the stack
        ldpha   r                       
        mvaa    data_line_ptr, line_ptr ; Replace line_ptr and r with data versions
        mva     data_r, r
        beq     @find_data              ; If 0 then we need to go look for a DATA statement
@read:
        inc     r                       ; Skip past the integer identifer
        jsr     decode_number           ; Decode the number into AX
        jsr     set_variable_value      ; Set the variable value
        clc
        jmp     @return

@find_data:
        ldy     #Line::number+1         ; Check MSB of line number
        lda     (line_ptr),y
        bmi     @error                  ; We're at line -1; no more DATA statemnets
        ldy     #Line::data             ; Get offset of statement
        lda     (line_ptr),y            ; Load the statement token
        cmp     #ST_DATA                ; See if it's a DATA statement
        beq     @found_data             ; Found DATA
        jsr     advance_line_ptr        ; No DATA here; try the next line
        jmp     @find_data

@found_data:
        mva     #Line::data+1, r        ; Initialize r to the byte following the DATA statement
        jmp     @read

@error:
        sec
@return:
        mva     r, data_r               ; Save data_ values and restore originals from stack
        mvaa    line_ptr, data_line_ptr
        plsta   r
        plstaa  line_ptr
        rts

; RESTORE statement:

exec_restore:
        mvaa    program_ptr, data_line_ptr  ; Restore line_ptr to beginning of program
        mva     #0, data_r
        rts

; Find the next DATA statement.

@check_line:
        ldy     #0
        lda     (line_ptr),y            ; Get the statement on this line
        cmp     #ST_DATA                ; DATA statement?
        beq     @found_data             ; Yep
        jsr     advance_line_ptr        ; Otherwise move to next statement
        jmp     @check_line             ; Keep looking

@found_data:
        mvaa    line_ptr, data_line_ptr ; Save line_ptr of DATA in read_line_ptr
        iny                             ; Set Y to 1
        lda     (data_line_ptr),y       ; After DATA token is argument count
        sta     data_count
        iny                             ; Set Y to 2
        sty     data_r                  ; Initialize the data count
        plstaa  line_ptr                ; Restore original line_ptr from stack
        rts

; DATA statement:
; Does nothing when executed.

exec_data:
        rts
