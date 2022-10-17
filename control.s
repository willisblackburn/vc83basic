.include "macros.inc"
.include "basic.inc"

exec_goto:
        jsr     decode_number           ; Go get the line number
        jsr     find_line               ; Find the program line
        mvax    line_ptr, next_line_ptr ; Store it as the next line; if line not found then it won't matter
        rts
