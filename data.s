.include "macros.inc"
.include "basic.inc"

.zeropage

; The line from which we're reading DATA values.
; If this points to the end of the program (line -1) then we're out of data.
data_line_ptr: .res 2

; The position from which we're reading DATA values.
data_r: .res 1

; How many values are left to read in the current DATA statement.
data_count: .res 1

.code 

; READ statement:

exec_read:
        jsr     decode_byte             ; Read the variable
        jsr     set_variable_value_ptr  ; Address of variable data in AX
        lda     data_r                  ; If 0 then we need to 

        rts

; RESTORE statement:

exec_restore:
        ldphaa  line_ptr                ; Save line_ptr
        mvaa    program_ptr, line_ptr   ; Restore line_ptr to beginning of program
        mva     #0, data_r

; Find the next DATA statement.

@check_line:
        ldy     #0
        lda     (line_ptr),y            ; Get the statement on this line
        cmp     ST_DATA                 ; DATA statement?
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
