
; READ statement:

exec_read_next_line:
        txa                             ; Transfer next line offset back from X
        clc
        adc     data_line_ptr           ; Add to data_line_ptr
        sta     data_line_ptr
        bcc     @skip_inc
        inc     data_line_ptr+1
@skip_inc:
        mva     #.sizeof(Line) + 2, data_line_pos   ; Skip 1 for DATA, 1 for next statement offset

; Fall through

exec_read:

; Advance data_line_ptr to a DATA line. It's either:
;   1. At the start of a DATA line: read the variable data
;   2. Somewhere within a DATA line: effectively the same as case 1
;   3. At the 0 at the end of a DATA line: try next line
;   4. At the start of a non-DATA line, such as the first line of the program: try next line
;   5. At the null line at the end of the program: return an error

        ldy     #Line::next_line_offset ; Check if data_line_ptr is at end of program (case 5)
        lda     (data_line_ptr),y
        tax                             ; Remember in X in case I need it to go to next line
        raieq   ERR_OUT_OF_DATA
        ldy     #.sizeof(Line) + 1      ; Check for DATA (add 1 to skip next statement offset)
        lda     (data_line_ptr),y
        cmp     #ST_DATA
        bne     exec_read_next_line     ; Not DATA; go to next line and try again (case 4)
        ldy     data_line_pos
        lda     (data_line_ptr),y       ; Check if we're pointing at the 0 at the end of the DATA line
        beq     exec_read_next_line     ; We are; move to the next line

; Now we're left with case 1 or case 2: somewhere on a DATA line

        jsr     decode_name             ; Read the variable name
        jsr     find_or_add_variable
        lda     decode_name_type        ; Is it a number or a string?
        bne     @string                 ; It's a string
        ldax    data_line_ptr           ; Point to data line
        ldy     data_line_pos
        jsr     string_to_fp            ; Parse the number
        jsr     @post_read
        jsr     push_fp0                ; Push FP0 onto the value stack

@assign:
        jsr     assign_variable         ; Store the value
        ldy     line_pos
        lda     (line_ptr),y            ; Peek next byte
        cmp     #','                    ; More variables?
        clc                             ; Prepare to return success
        bne     @done                   ; Nope
        inc     line_pos
        bne     exec_read               ; Unconditional

@done:
        rts

@string:
        ldax    data_line_ptr           ; Point to data line
        ldy     data_line_pos
        jsr     read_string
        jsr     @post_read
        jsr     push_string             ; Push result string onto the stack
        jmp     @assign

@post_read:
        bcs     @format_error           ; If we got here with carry set then number or string read failed
        jsr     read_argument_separator
        sty     data_line_pos           ; Update data_line_pos to next read position
        bcc     @done                   ; Read separator
        beq     @done                   ; No separator, but did find EOL

@format_error:
        raise   ERR_FORMAT_ERROR

; RESTORE statement:

exec_restore:
        jsr     reset_data

; Fall through

; REM and DATA statements:
; Do nothing when encountering these two statements.

exec_rem:
exec_data:
        clc
        rts
