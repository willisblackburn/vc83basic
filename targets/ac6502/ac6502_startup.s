; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn / 2026 A.C. Wright
;
; SPDX-License-Identifier: MIT
;
; ac6502 cartridge entry point.  The cartridge ROM occupies $C000-$FFFF
; and owns the CPU vectors at $FFFA-$FFFF.  On RESET the CPU jumps to
; `startup`, which performs BIOS hardware initialization via KernalInit
; and then transfers control to the BASIC interpreter.
;
; This is the BIOS README's "Pattern B" (KernalInit + beep), with the
; cartridge taking over the BRK vector -- see brk_handler below.
;
; See https://github.com/acwright/6502 for more info

.export startup

.segment "STARTUP"

startup:
        sei                             ; Disable interrupts during bring-up
        cld                             ; Clear decimal flag
        ldx     #$FF
        txs                             ; Initialize the CPU stack to $FF
        jsr     KernalInit              ; Probe & initialize all BIOS hardware.
                                        ; Sets IRQ/BRK/NMI RAM vectors and IO_MODE.
                                        ; Leaves interrupts disabled; caller must CLI.

        ; KernalInit points BRK_PTR at the BIOS handler, which ends in a jump
        ; to the Monitor at $EE00 -- an address this cartridge has overlaid
        ; with its own code.  Take the vector over before anything can BRK.
        lda     #<brk_handler
        sta     BRK_PTR
        lda     #>brk_handler
        sta     BRK_PTR + 1

        jsr     Beep                    ; Play the startup beep
        cli                             ; Enable interrupts (keyboard, serial RX)

        ; Clear the screen.  Neither KernalInit nor InitVideo touches the name
        ; table -- InitVideo only writes the mode registers and reloads the
        ; character set -- so without this a reset leaves the previous
        ; session's text on screen underneath the banner.  VideoClear tests
        ; HW_PRESENT itself and returns immediately on a machine with no video
        ; card, so this is safe on a serial-only console.
        jsr     VideoClear

        ; BSS is not zeroed on bare metal, and `write` -> `putch` polls for a
        ; break whenever program_state says a program is running.  Settle it
        ; before the banner, which runs ahead of initialize_program.
        lda     #PS_READY
        sta     program_state

        jsr     display_startup_banner  ; Display the BASIC banner
        jmp     main                    ; Enter the BASIC REPL (never returns)

; BRK handler -- reached from the Kernal's IRQ dispatcher via BRK_PTR, with
; A/X/Y already restored and the CPU's pushed P/PCL/PCH still on the stack.
; Reports where it happened and drops back to the READY prompt rather than
; wedging the machine.  Raising ERR_STOPPED (rather than jumping straight to
; the prompt) is what restores the interpreter's expression stack.

brk_handler:
        pla                             ; Discard the pushed P
        pla                             ; PCL -- as with the BIOS Monitor, the
        sta     D                       ;   reported address is the BRK + 2
        pla                             ; PCH
        sta     E
        ldax    #brk_message
        jsr     ex_print_cstr
        lda     E                       ; Address, high byte first
        jsr     ex_print_2h
        lda     D
        jsr     ex_print_2h
        jsr     newline
        raise   ERR_STOPPED

brk_message:
        .byte   "BRK AT $", 0

; IRQ / NMI trampolines -- dispatch through the RAM vectors that
; KernalInit configured so the BIOS's own handlers stay in charge.

irq_trampoline:
        jmp     (IRQ_PTR)

nmi_trampoline:
        jmp     (NMI_PTR)

; CPU hardware vectors -- owned by the cartridge ROM.
.segment "VECTORS"

        .word   nmi_trampoline          ; NMI
        .word   startup                 ; RESET
        .word   irq_trampoline          ; IRQ / BRK

.code
