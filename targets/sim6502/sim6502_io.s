; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

; cc65 runtime
.import push0, push1, pusha0, pushax

; sim65 POSIX vectors
.import _open, _close, _read, _write


; Mode flag constants for cc65 / POSIX open()
; Mode 1 (Read):   O_RDONLY = $01
; Mode 2 (Write):  O_WRONLY | O_CREAT | O_TRUNC = $02 | $10 | $20 = $32
; Mode 3 (Update): O_RDWR | O_CREAT = $03 | $10 = $13
; Mode 4 (Append): O_WRONLY | O_CREAT | O_APPEND = $02 | $10 | $40 = $52

.data

channel_fds:
        .byte   0, $FF, $FF, $FF, $FF, $FF, $FF, $FF   ; Ch 0 = stdin/stdout, 1..7 = closed

.bss

open_mode:        .res 1
open_flags:       .res 1
get_byte_buf:     .res 1
put_byte_buf:     .res 1
console_column:   .res 1
save_load_fd:     .res 1

.code

; Copies string currently described in S0 (length in BC) to buffer with a null terminator.

copy_s0_to_buffer_nul:
        ldy     #0
        lda     (BC),y                  ; Length byte of string in S0
        tay
        beq     @empty
        tax                             ; Length in X
        ldy     #0
@loop:
        lda     (S0),y
        sta     buffer,y
        iny
        dex
        bne     @loop
@empty:
        lda     #0
        sta     buffer,y
        rts

posix_mode_table:
        .byte   $01                     ; 0 = Read:   O_RDONLY
        .byte   $32                     ; 1 = Write:  O_WRONLY | O_CREAT | O_TRUNC
        .byte   $13                     ; 2 = Update: O_RDWR | O_CREAT
        .byte   $52                     ; 3 = Append: O_WRONLY | O_CREAT | O_APPEND

; Opens a file on channel.
; S0 = filename string
; A = mode (0 = read, 1 = write, 2 = update, 3 = append)
; channel = channel index (0..7)
; Returns carry clear if ok, carry set if error.

open:
        sta     open_mode
        lda     channel
        and     #$07
        tax
        lda     channel_fds,x           ; Check if already open
        cmp     #$FF
        bne     @error                  ; Already open -> fail

        lda     open_mode
        and     #$03                    ; Access mode: 0 (Read), 1 (Write), 2 (Update), 3 (Append)
        tay
        lda     posix_mode_table,y
        sta     open_flags

@call_open:
        jsr     copy_s0_to_buffer_nul
        ldax    #buffer
        jsr     pushax                  ; Push filename pointer
        lda     open_flags
        jsr     pusha0                  ; Push open flags
        lda     #$FF                    ; Mode 0777 permission ($01FF)
        ldx     #$01
        jsr     pushax
        ldy     #6                      ; 3 arguments (6 bytes)
        jsr     _open                   ; Call C open()
        cpx     #$80                    ; Negative return value?
        bcs     @error
        tay                             ; Save fd in Y
        lda     channel
        and     #$07
        tax                             ; Channel index in X
        tya                             ; Restore fd in A
        sta     channel_fds,x           ; Save file descriptor
        clc
        rts

@error:
        sec
        rts

; Closes channel.
; channel = channel (0..7)
; Returns carry clear.

close:
        lda     channel
        and     #$07
        tax
        beq     @done                   ; Channel 0 (console) is never closed
        lda     channel_fds,x           ; Get fd
        cmp     #$FF
        beq     @done                   ; If already closed, leave it closed
        pha
        lda     #$FF                    ; Mark closed
        sta     channel_fds,x
        pla
        ldx     #0
        jsr     _close
@done:
        clc
        rts

; Closes all open channels (1..7). Called by NEW / CLR.

close_all:
        lda     #7
        sta     channel
@loop:
        jsr     close
        dec     channel
        bne     @loop
        rts

; Gets a single byte from channel.
; channel = channel (0..7)
; Returns byte in A and carry clear if ok, carry set if EOF / error.

getch:
        txa
        pha
        tya
        pha
        lda     channel
        and     #$07
        tax
        cpx     #0
        bne     @check_open
        lda     #0                      ; fd 0 (stdin)
        beq     @do_read
@check_open:
        lda     channel_fds,x           ; Get fd
        cmp     #$FF
        beq     @error
@do_read:
        jsr     pusha0                  ; Push fd
        ldax    #get_byte_buf           ; Buffer = &get_byte_buf
        jsr     pushax                  ; Push buffer address
        lda     #1                      ; Length = 1
        ldx     #0
        jsr     _read                   ; Returns bytes read in AX
        cpx     #$80                    ; Error?
        bcs     @error
        cmp     #0
        bne     @got_byte
        cpx     #0
        beq     @error                  ; 0 bytes read = EOF
@got_byte:
        pla
        tay
        pla
        tax
        lda     get_byte_buf            ; Load byte read
        clc
        rts

@error:
        pla
        tay
        pla
        tax
        sec
        rts

; Polls for a key from console without blocking.
; sim65 simulator does not support non-blocking keyboard polling.
; Returns carry set (no key).

inkey:
        sec
        rts

; Puts a single byte to channel.
; A = byte to put
; channel = channel (0..7)
; Returns carry clear if ok, carry set if error.

putch:
        sta     put_byte_buf            ; Store byte in put_byte_buf
        txa
        pha
        tya
        pha
        lda     channel
        and     #$07
        tax
        cpx     #0
        beq     @stdout
        lda     channel_fds,x
        cmp     #$FF
        beq     @error
        jmp     @write_fd

@stdout:
        inc     console_column
        lda     #1                      ; fd 1 (stdout)

@write_fd:
        jsr     pusha0                  ; Push fd
        ldax    #put_byte_buf           ; Buffer = &put_byte_buf
        jsr     pushax                  ; Push buffer address
        lda     #1                      ; Length = 1
        ldx     #0
        jsr     _write                  ; Call C write()
        cpx     #$80
        bcs     @error
        pla
        tay
        pla
        tax
        clc
        rts

@error:
        pla
        tay
        pla
        tax
        sec
        rts

; Reads a text record (line) from channel into buffer.
; Returns line length in A and carry clear if ok, carry set on EOF / error.

readline:
        lda     channel
        and     #$07
        tax
        cpx     #0
        bne     @file_channel
        ; Channel 0 (console stdin)
        jsr     push0                   ; fd 0
        lda     #<buffer
        ldx     #>buffer
        jsr     pushax
        lda     #BUFFER_SIZE-1
        ldx     #0
        jsr     _read
        cpx     #$80
        bcs     @fc_err
        tax                             ; Length in X
        beq     @fc_err                 ; 0 bytes read = EOF
        lda     buffer-1,x
        cmp     #$0A                    ; Trailing newline?
        bne     @no_strip
        dex                             ; Strip trailing newline
@no_strip:
        mva     #0, console_column
        txa                             ; Return length in A
        clc
        rts

@file_channel:
        lda     channel_fds,x           ; Check if open
        cmp     #$FF
        beq     @fc_err
        txa
        pha                             ; Push channel index onto hardware stack
        lda     #0
        pha                             ; Push buffer offset (0) onto hardware stack
@read_loop:
        tsx
        lda     $102,x                  ; Channel index
        sta     channel
        jsr     getch                   ; Read 1 byte
        bcs     @eof_check
        tsx
        ldy     $101,x                  ; Buffer offset
        cmp     #$0A                    ; Line feed (LF)?
        beq     @line_done
        cmp     #$0D                    ; Carriage return (CR)?
        beq     @line_done
        sta     buffer,y
        iny
        tya
        tsx
        sta     $101,x                  ; Save updated buffer offset
        cpy     #BUFFER_SIZE-1
        bcc     @read_loop
@line_done:
        pla                             ; Pop buffer offset
        tay                             ; Buffer length in Y
        pla                             ; Pop channel index
        tya                             ; Return length in A
        clc
        rts

@eof_check:
        tsx
        ldy     $101,x                  ; Buffer offset
        cpy     #0
        bne     @line_done
        pla
        pla
@fc_err:
        sec
        rts

; Emits record delimiter (newline) on channel.

newline:
        lda     #$0A
        jsr     putch
        mva     #0, console_column
        rts

; Emits field separator (tabs to next 16-column boundary).

tab:
        lda     #' '
        jsr     putch
        lda     console_column
        and     #$0F
        bne     tab
        rts

; Saves program memory to file.
; S0 = filename string

save:
        jsr     copy_s0_to_buffer_nul
        ldax    #buffer
        jsr     pushax                  ; Filename
        lda     #$32                    ; O_WRONLY | O_CREAT | O_TRUNC
        jsr     pusha0
        lda     #$FF                    ; 0777
        ldx     #$01
        jsr     pushax
        ldy     #6
        jsr     _open
        cpx     #$80
        bcs     @err
        sta     save_load_fd            ; Save fd

        jsr     pusha0                  ; Push fd
        lda     #<(__BSS_RUN__ + __BSS_SIZE__)
        ldx     #>(__BSS_RUN__ + __BSS_SIZE__)
        jsr     pushax                  ; Push buffer pointer
        sec
        lda     variable_name_table_ptr
        sbc     #<(__BSS_RUN__ + __BSS_SIZE__)
        pha
        lda     variable_name_table_ptr+1
        sbc     #>(__BSS_RUN__ + __BSS_SIZE__)
        tax
        pla                             ; Length in AX
        jsr     _write                  ; Call write(fd, ptr, len)
        cpx     #$80
        bcs     @close_err

        lda     save_load_fd
        ldx     #0
        jsr     _close
        clc
        rts

@close_err:
        lda     save_load_fd
        ldx     #0
        jsr     _close
@err:
        sec
        rts

; Loads program memory from file.
; S0 = filename string

load:
        jsr     copy_s0_to_buffer_nul
        ldax    #buffer
        jsr     pushax                  ; Filename
        lda     #$01                    ; O_RDONLY
        jsr     pusha0
        lda     #$FF                    ; 0777
        ldx     #$01
        jsr     pushax
        ldy     #6
        jsr     _open
        cpx     #$80
        bcs     @err
        sta     save_load_fd

        jsr     pusha0                  ; Push fd
        lda     #<(__BSS_RUN__ + __BSS_SIZE__)
        ldx     #>(__BSS_RUN__ + __BSS_SIZE__)
        jsr     pushax                  ; Push buffer pointer
        sec
        lda     himem_ptr
        sbc     #<(__BSS_RUN__ + __BSS_SIZE__)
        pha
        lda     himem_ptr+1
        sbc     #>(__BSS_RUN__ + __BSS_SIZE__)
        tax
        pla                             ; Max length in AX
        jsr     _read                   ; Returns bytes read in AX
        cpx     #$80
        bcs     @close_err
        stax    src_ptr                 ; Save bytes read

        cpx     #0
        bne     @check_magic
        cmp     #4 + .sizeof(Line)
        bcc     @format_err

@check_magic:
        ldy     #3
@check_loop:
        lda     __BSS_RUN__ + __BSS_SIZE__,y
        cmp     vbas_header,y
        bne     @format_err
        dey
        bpl     @check_loop

        clc
        lda     src_ptr
        adc     #<(__BSS_RUN__ + __BSS_SIZE__)
        sta     variable_name_table_ptr
        lda     src_ptr+1
        adc     #>(__BSS_RUN__ + __BSS_SIZE__)
        sta     variable_name_table_ptr+1

        lda     save_load_fd
        ldx     #0
        jsr     _close

        jsr     clear_variables
        jsr     reset_program
        clc
        rts

@format_err:
        lda     save_load_fd
        ldx     #0
        jsr     _close
        jsr     initialize_program      ; Restore valid empty program
        sec
        rts

@close_err:
        lda     save_load_fd
        ldx     #0
        jsr     _close
@err:
        sec
        rts

; Device-specific control operation.
; channel = channel (0..7), A = command, BC = arg1, DE = arg2
; Returns carry clear if ok, carry set if error.

xio:
        clc
        rts
