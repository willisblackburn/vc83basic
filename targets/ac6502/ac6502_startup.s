; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn / 2026 A.C. Wright
;
; SPDX-License-Identifier: MIT
;
; ac6502 cartridge entry point.  The cartridge ROM occupies $C000-$FFFF
; and owns the CPU vectors at $FFFA-$FFFF.  On RESET the CPU jumps to
; `startup`, which performs BIOS hardware initialization via KernalInit
; and then transfers control to the BASIC interpreter.
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
        jsr     Beep                    ; Play the startup beep
        cli                             ; Enable interrupts (keyboard, serial RX)
        jsr     display_startup_banner  ; Display the BASIC banner
        jmp     main                    ; Enter the BASIC REPL (never returns)

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
