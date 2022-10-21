.include "macros.inc"
.include "basic.inc"

exec_goto:
        jsr     decode_number           ; Go get the line number
        jsr     find_line               ; Find the program line
        rts                             ; Either next_line_ptr is set or carry (error) is set
