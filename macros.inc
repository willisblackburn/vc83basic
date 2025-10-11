; Macros

; Inserts a BRK instruction followed by a value.
; On the sim6502 platform the BRK will print the value followed by the 6502 registers.

.macro debug value
        brk
        .byte   value
.endmacro

; Loads or stores a 16-bit value to/from AX.

.macro ldax address
    .if (.match (.left (1, {address}), #))
        lda     #<(.right (.tcount ({address})-1, {address}))
        ldx     #>(.right (.tcount ({address})-1, {address}))
    .else
        lda     address
        ldx     address+1
    .endif
.endmacro

.macro lday address
    .if (.match (.left (1, {address}), #))
        lda     #<(.right (.tcount ({address})-1, {address}))
        ldy     #>(.right (.tcount ({address})-1, {address}))
    .else
        lda     address
        ldy     address+1
    .endif
.endmacro

.macro stax address
        sta     address
        stx     address+1
.endmacro

.macro stay address
        sta     address
        sty     address+1
.endmacro

; Moves an 8-bit value through A, X, or Y.

.macro mva from, to
        lda     from
        sta     to
.endmacro

.macro mvx from, to
        ldx     from
        stx     to
.endmacro

.macro mvy from, to
        ldy     from
        sty     to
.endmacro

; Moves a 16-bit value through A.

.macro mvaa from, to
    .if (.match (.left (1, {from}), #))
        lda     #<(.right (.tcount ({from})-1, {from}))
        sta     to
        lda     #>(.right (.tcount ({from})-1, {from}))
        sta     to+1
    .else
        lda     from
        sta     to
        lda     from+1
        sta     to+1
    .endif
.endmacro

; Moves a 16-bit value through AX.

.macro mvax from, to
        ldax    from
        stax    to
.endmacro

; Moves a 16-bit value through AY.

.macro mvay from, to
        lday    from
        stay    to
.endmacro

; Pushes a memory value onto the stack via A.

.macro ldpha value
        lda     value
        pha 
.endmacro

; Pushes a 16-bit memory value onto the stack via A. Note the value is pushed in reverse byte order (big-endian).

.macro ldphaa value
        ldpha   value
        ldpha   value+1
.endmacro

; Pushes a 16-bit value from AX onto the stack. Note the value is pushed in reverse byte order (big-endian).

.macro phax 
        pha
        txa
        pha
.endmacro

; Pushes a 16-bit value from AY onto the stack. Note the value is pushed in reverse byte order (big-endian).

.macro phay
        pha
        tya
        pha
.endmacro

; Pulls a value from the stack to memory via A.

.macro plsta value
        pla
        sta     value
.endmacro

; Pulls a 16-bit big-endian value from the stack to memory via A.

.macro plstaa value
        plsta   value+1
        plsta   value
.endmacro

; Pulls a 16-bit big-endian value from the stack into AX.

.macro plax
        pla
        tax
        pla
.endmacro

; Pulls a 16-bit big-endian value from the stack into AY.

.macro play
        pla
        tay
        pla
.endmacro

; Pushes `size` bytes from zero page onto the stack starting at `address`.

.macro phzp address, size
    .if (size = 1)
        ldpha   address
    .elseif (size = 2)
        ldphaa  address
    .else
        ldx     #(256 - size)           ; After size increments, X will wrap around to 0
:
        lda     address + size,x        ; Load ZP value
        pha                             ; First iteration, adding size + X = 256, wraps around to address
        inx
        bne     :-
    .endif
.endmacro

; Pulls `size` bytes from the stack into zero page starting at `address`.

.macro plzp address, size
    .if (size = 1)
        plsta   address
    .elseif (size = 2)
        plstaa  address
    .else
        ldx     #size                   ; Pop size bytes
:
        pla
        dex                             ; Decrement to save index; sets Z flag it's zero
        sta     address,x
        bne     :-
    .endif
.endmacro

; Increments a 16-bit value stored in XY.

.macro inxy
        inx
        bne     :+
        iny
:
.endmacro

; Raises an error.

.macro raise error
    .if (.not .match ({error}, A))
        lda     #error
    .endif
        jmp     on_raise
.endmacro

; Raises an error if carry is clear.

.macro raicc error
        bcs     :+
        raise   error
:
.endmacro

; Raises an error if carry is set.

.macro raics error
        bcc     :+
        raise   error
:
.endmacro

; Raises an error if the Z flag is set.

.macro raieq error
        bne     :+
        raise   error
:
.endmacro

; Raises an error if the Z flag is clear.

.macro raine error
        beq     :+
        raise   error
:
.endmacro
