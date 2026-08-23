---
name: 6502-space-optimization
description: >-
  Use this skill when optimizing 6502 assembly code for size. Contains a catalog
  of micro-optimizations that save 1-5 bytes each. Activate when working on
  reducing code size, when the binary is too large to fit in its target, or when
  reviewing code for space-saving opportunities.
---

# 6502 Code Size Micro-Optimizations

This skill catalogs specific techniques for reducing 6502 code size, typically saving 1–5 bytes
each. These are drawn from both well-known 6502 optimization resources and from this project's
own git history.

The core VC83 BASIC interpreter must fit in 8K. Every byte counts.

---

## 1. Eliminate Redundant CLC and SEC

The carry flag state is often known after branches and comparisons. Removing a redundant `CLC` or
`SEC` saves 1 byte each.

### After branches that test carry

If code is reached via `BCC`, the carry is guaranteed clear. If reached via `BCS`, the carry is
guaranteed set. A `CLC` after `BCC` or a `SEC` after `BCS` is a no-op.

```assembly
; BEFORE (5 bytes)
        cmp     #$10
        bcc     @skip
        sec                     ; Redundant: CMP set carry since we didn't branch
        sbc     #$10
@skip:

; AFTER (4 bytes)
        cmp     #$10
        bcc     @skip
        sbc     #$10            ; Carry already set from CMP
@skip:
```

### After CMP/CPX/CPY

Comparison instructions always set carry (C=1) if A >= operand. If subsequent code needs `SEC`
before an `SBC`, and you know the comparison didn't borrow, the `SEC` is redundant.

**Project example** (`9156d404`): Replaced `SEC` + `SBC` with `CMP` + `SBC` for a 16-bit
comparison, saving 1 byte. The low-byte comparison only needs to set carry for the high-byte
`SBC`; it doesn't need to actually compute the difference:

```assembly
; BEFORE
        sec
        lda     src_ptr
        sbc     himem_ptr       ; Low byte subtract
        lda     src_ptr+1
        sbc     himem_ptr+1     ; High byte subtract

; AFTER
        lda     src_ptr
        cmp     himem_ptr       ; Low byte compare (sets carry correctly)
        lda     src_ptr+1
        sbc     himem_ptr+1     ; High byte subtract
```

### After multi-byte arithmetic

In a multi-byte add or subtract, only the first byte needs `CLC`/`SEC`. Subsequent bytes use the
carry output from the previous byte automatically.

### Rearranging to exploit known carry

Sometimes you can rearrange a sequence so that the `CLC` or `SEC` becomes unnecessary. If code
naturally falls through from an operation that leaves carry in the right state, the explicit flag
set can be removed.

**Project example** (`d25fc3f7`): Removed a `CLC` at the end of `assign_variable` that was
unnecessary because callers didn't depend on the carry state.

---

## 2. Eliminate Redundant Register Loads

Every `LDA`, `LDX`, or `LDY` with an immediate operand costs 2 bytes. If the register already
holds the needed value, the load can be removed.

### Track register contents across operations

When a register already contains the value you need, don't reload it. This requires careful
tracking of what each register holds at every point in the code.

**Project example** (`772ae367`): In `string_to_fp`, after popping the mantissa value from
the stack into A, the code used to store it into D and then reload it from D for each branch.
By restructuring, the `LDA D` instructions were eliminated because A already held the value:

```assembly
; BEFORE (9 bytes)
        pla                     ; Pop mantissa D
        sta     D
        lda     FP0s            ; Was exponent negative?
        bmi     @exp_neg
        lda     D               ; Positive: D = D - FP0t
        sec
        sbc     FP0t
        ...
@exp_neg:
        lda     D               ; Negative: D = D + FP0t

; AFTER (6 bytes, saves 3)
        pla                     ; Pop mantissa D
        bit     FP0s            ; Test sign without clobbering A
        bmi     @exp_neg
        sec                     ; Positive: A = A - FP0t
        sbc     FP0t
        ...
@exp_neg:                       ; Negative: A = A + FP0t (A still has mantissa)
```

### Eliminate TAX/TXA round-trips

If a value passes through A to X and then back, look for ways to keep it in the right register
from the start.

**Project example** (`aa899759`): The dispatch code did `AND #$3F` / `TAX` / ... / `TXA` to
put the dispatch index through X and back to A. By deferring the `TAX` to the point where X was
actually needed, two `TAX` instructions and one `TXA` were eliminated, saving 2 bytes.

### Use BIT to test without clobbering A

`BIT addr` tests bits 7 and 6 of a memory location, setting N and V flags, without modifying A.
This is cheaper than `LDA` + test + reload when you need to preserve A:

```assembly
; BEFORE (4 bytes)
        lda     FP0s
        bmi     @negative
        lda     original_value  ; Have to reload

; AFTER (3 bytes)
        bit     FP0s            ; Sets N from bit 7, preserves A
        bmi     @negative
```

### Document what functions leave in registers

By establishing conventions about what registers hold on function return, callers can skip
redundant loads.

**Project example** (`efbf2893`, `33b4b9dc`): `skip_whitespace` was documented to leave the
buffer position in X. Multiple callers had `jsr skip_whitespace` / `ldx bp`, which became just
`jsr skip_whitespace`, saving 2 bytes at each call site.

---

## 3. Replace JMP with Branch

`JMP` is 3 bytes; a conditional branch is 2 bytes. If a processor flag is in a known state, a
conditional branch can replace a `JMP`, saving 1 byte. The branch target must be within -128 to
+127 bytes.

### Use unconditional-in-context branches

After any instruction that guarantees a flag state, use the appropriate branch:

```assembly
; After INX/INY/INC (when result is known non-zero): BNE is unconditional
; After DEX/DEY/DEC (when result wraps to $FF, not zero): BNE is unconditional
; After LDA #nonzero: BNE is unconditional
; After AND where result is known non-zero: BNE is unconditional
; After CMP where A is known < 128: BPL is unconditional
```

**Project example** (`54f19888`): In `list_statement`, `append_buffer` always returns with carry
clear, so `jmp @next` was replaced with `bcc @next`, saving 1 byte.

**Project example** (`60aa5b79`): In `find_line`, a loop was restructured so that
`advance_next_line_ptr` (which leaves Z=0 because it sets Y=3) is followed by `bne @loop` instead
of `jmp @loop`:

```assembly
; BEFORE
@next_line:
        jsr     advance_next_line_ptr
@test_line:
        jsr     compare_next_line_to_target
        bcc     @next_line

; AFTER
@loop:
        jsr     compare_next_line_to_target
        bcc     @advance
        ...
@advance:
        jsr     advance_next_line_ptr
        bne     @loop           ; Unconditional: Y=3 from set_next_line_pos
```

### Ensure subroutines document flag state on return

When a subroutine always clears carry on success (a common convention), callers can use `BCC`
instead of `JMP` to branch unconditionally after the call.

---

## 4. Replace JSR+RTS with JMP (Tail Call Optimization)

When a subroutine's last action is `JSR target` / `RTS`, replace with `JMP target`. The called
routine's `RTS` returns directly to the original caller. Saves 1 byte.

**Project example** (`f06397df`): Applied this pattern in five places across the codebase:

```assembly
; BEFORE (4 bytes)
        jsr     store_fp0
        rts

; AFTER (3 bytes)
        jmp     store_fp0
```

This also applies to conditional tail calls where the JSR is the last thing before RTS on a
particular code path.

**Project example** (`718062e4`): `fun_sqr` ended with `jsr fexp` / `rts`, replaced with
`jmp fexp`.

---

## 5. Merge Common Code by Falling Through

Arrange subroutines so that one falls through into the next, eliminating a `JMP` or `JSR`+`RTS`.

### Move subroutines to enable fall-through

If routine A always calls routine B as its last action, place B immediately after A and remove the
call entirely.

**Project example** (`afaf8f2c`): Moved the LET handler inline into `dispatch.s` so that
`exec_impl_let` falls through to `assign_variable`, eliminating a `JMP`.

**Project example** (`c408ca53`): Moved `restore_next_line_ptr` so that `exec_next` falls through
to it on the continue path, and converted error raises to local labels that other routines could
also branch to, eliminating multiple `JMP` instructions.

### Share error handlers

If multiple routines need the same error raise, place it where one of them can fall through and
the others can branch to it:

```assembly
; Save 3 bytes each time a JMP to the error handler is replaced by a branch
        bne     raise_invalid_variable  ; Branch replaces jmp
        ...
raise_invalid_variable:
        raise   ERR_INVALID_VARIABLE
```

---

## 6. Consolidate Common Instruction Sequences

When the same sequence of 2–3 instructions appears in multiple places, factor it into a small
subroutine. The `JSR` costs 3 bytes but each eliminated copy saves more.

**Project example** (`fffd6b8c`): Created `pop_int_fp0` (= `jsr pop_fp0` + `jmp
truncate_fp_to_int`) and `pop_string_s0` (= `jsr pop_string` + `jmp load_s0`). Each call site
that previously had two `JSR`s (6 bytes) now has one (3 bytes), saving 3 bytes per call site.

**Project example** (`d44b1b48`): Consolidated duplicated right-shift logic from
`truncate_fp_to_int32` and `fadd` into a single `shift_fp0_right` function, saving 49 bytes.

### The break-even point

A subroutine wrapper costs 6 bytes (the subroutine itself: 3 for `JSR`, 3 for `JMP` or the
inlined code, plus `RTS`). It saves 3 bytes per additional call site. So:
- 2 call sites: may break even or save a few bytes
- 3+ call sites: definite win

---

## 7. Combine Tests with ORA/AND

When checking multiple conditions that should all be zero (or all non-zero), combine them with
`ORA` or `AND` instead of separate branch-on-each:

**Project example** (`60aa5b79`): FOR loop validation checked both `var_name_type` and
`arity` for zero. Two separate loads and branches (4 bytes: `LDA` + `BNE` + `LDA` +
`BMI`) became one combined check (3 bytes: `LDA` + `ORA` + `BNE`):

```assembly
; BEFORE (6 bytes)
        lda     var_name_type
        bne     raise_invalid_variable
        lda     arity
        bmi     raise_invalid_variable

; AFTER (5 bytes)
        lda     var_name_type
        ora     arity
        bne     raise_invalid_variable
```

---

## 8. Use Arithmetic Tricks

### Adjust immediate values to account for known carry

If you know carry is set and need to add N, use `ADC #N-1` (since ADC adds carry). If carry is
clear and you need to subtract N, use `SBC #N-1` (since SBC subtracts the inverse of carry).

```assembly
; Carry is known to be set from CMP
; BEFORE (3 bytes)
        clc
        adc     #5

; AFTER (2 bytes)
        adc     #4              ; Adds 4 + carry(1) = 5
```

### Negate with EOR + ADC when carry is set

The two's complement negation `-A = ~A + 1` can be done in 2 instructions if carry is already
set:

```assembly
; Carry is set from a prior comparison
        eor     #$FF            ; ~A
        adc     #0              ; ~A + 1 = -A (because carry is set)
```

**Project example** (`718062e4`): In `fadd`, replaced `EOR #$FF` / `CLC` / `ADC #1` with
`EOR #$FF` / `ADC #0` because carry was known to be set from a preceding `SBC`, saving 1 byte.

### Invert subtraction direction

If computing `A - M` requires loading both values, consider whether `M - A` (with negation)
or `A + (~M) + 1` would be cheaper in context, especially if one value is already in a register.

### Use ASL/LSR for flag manipulation

`ASL zp` shifts left, clearing bit 0 and moving bit 7 into carry. `LSR zp` shifts right, clearing
bit 7 and moving bit 0 into carry. These are useful for flag bytes:

**Project example** (`4012af12`): `fun_abs` used `mva #0, FP0s` (3 bytes with macro expansion) to
clear the sign. Replaced with `asl FP0s` (2 bytes) which shifts the sign bit out, effectively
clearing it. Similarly, `sec` / `ror FP0s` sets bit 7 (the sign bit) in 3 bytes vs. `mva #$80,
FP0s` in 4.

### Use CMP instead of SEC+SBC when you only need flags

If you only need the flag result of a subtraction (not the computed difference), use `CMP` instead
of `SEC` + `SBC`. `CMP` implicitly sets carry and doesn't need a preceding `SEC`.

**Project example** (`9156d404`): In `find_array_element`, the code did `SEC` / `SBC
array_element_size` / `TXA` / `SBC array_element_size+1` just to check if the result was
negative. Replaced the low byte with `CMP array_element_size` since only the carry into the
high byte mattered, saving 1 byte.

### Move bit 7 to carry or clear bit 7 with CMP #$80

If you need to move bit 7 (the N bit) to the carry flag without affecting the value in A, use `CMP #$80`:
- If bit 7 was set ($A \ge \$80$), carry is set ($C=1$).
- If bit 7 was clear ($A < \$80$), carry is clear ($C=0$).
- The accumulator value `A` is preserved.

If you need to clear bit 7 but remember whether it was set, use the sequence `CMP #$80` followed by `AND #$7F`. Because `AND` (along with `ORA` and `EOR`) does not affect the carry flag:
- `A` has bit 7 cleared.
- The carry flag preserves the original state of bit 7 ($C=1$ if it was set, $C=0$ if clear), enabling conditional branching (`BCC`/`BCS`) or arithmetic without needing `PHA`/`PLA` stack operations.
---

## 9. Restructure Static Data for Cheaper Access

### Use byte offsets instead of address tables

If a data structure has entries that can be addressed by a byte offset from a known base, use
direct indexed addressing (`LDA base,Y`) instead of a split-address lookup table.

**Project example** (`fd21cce6`): The lexer's DFA used split high/low address tables
(`state_table_low` and `state_table_high`) to look up state addresses via indirect addressing
`(vector_ptr),Y`. By switching state transitions to use byte offsets relative to `state_0`, the
address tables were eliminated entirely, and states were accessed with `LDA state_0,Y` (absolute
indexed). This saved both the table data and the pointer setup code.

### Pack metadata into compact formats

**Project example** (`215d0458`): Parser's TOKENIZE op used 16-bit absolute addresses. By
switching to 12-bit relative offsets and putting the parser data in a segment guaranteed to be
nearby, the unique address-reading code was eliminated. Saved 14 bytes.

**Project example** (`b764c358`, `861c536e`): Function dispatch metadata (arity, prolog/epilog
actions) was packed into 4-bit nibbles, two per byte, in a `dispatch_flags` table. This halved the
table size and allowed a single `dispatch_entry` routine to handle both statements and functions.

### Use Structure of Arrays (SoA) for pointer tables

Split interleaved `low, high, low, high` pointer tables into separate `table_low` and `table_high`
arrays. This allows simple indexed access (`LDA table_low,X` / `LDA table_high,X`) instead of
computing `X*2` offsets.

---

## 10. Inline Small Functions

If a function is only called from one or two places and is very short, inlining it can save the
3-byte `JSR` and 1-byte `RTS` overhead.

**Project example** (`66de27ea`): The RND function had separate `rnd_generate` and `rnd_reseed`
helper functions. By inlining them into `fun_rnd`, the `JSR`+`RTS` overhead of two functions was
eliminated, and shared code between the seed and generate paths (like the copy loop) was
deduplicated. Saved 12 bytes.

Conversely, if a function is called from many places, extracting it saves space. The key is
finding the right balance.

---

## 11. Merge Duplicate Code Paths

When two code paths do almost the same thing, look for ways to merge them.

**Project example** (`5f748960`): In `string_to_fp`, the character consumption code for digits,
decimal points, and sign characters all ended with `INY` + unconditional branch back to the loop.
These were merged into a single `@consume` label, eliminating two copies of the `INY`/branch pair.

**Project example** (`54f19888`): LIST had separate paths for core vs. extension function name
lookup that differed only in the table pointer setup. Merged into a single path with a branch to
select the table.

**Project example** (`83f6a437`): Extension statement and function dispatch had nearly identical
code. By using arithmetic to map extension tokens into the same index space as core tokens (using
`SBC` with a constant that accounts for the carry and the TOKEN_EXTENSION offset), both paths
merged into one `JMP invoke_indexed_vector`.

---

## 12. Exploit Known Function Side Effects

### Use non-obvious register and flag return values

Track what registers and flags contain after every instruction and function call. Often a function
leaves a register or flag in a useful state on return (such as leaving an index in X, a counter at zero,
or carry clear on success) that callers can use directly instead of reloading or retesting.

### Use loop counters that end at useful values

Design loops so the counter register ends at a value needed by subsequent code:

```assembly
; Copy 4 bytes using X counting down from 4 to 0
        ldx     #4
@copy:  lda     src-1,x
        sta     dst-1,x
        dex
        bne     @copy
        ; X is now 0, which we can use directly
        stx     FP0s            ; FP0s = 0
```

---

## 13. Shorten String and Data Constants

**Project example** (`dcca5701`): Changed `"ERROR: "` to `"ERR: "`, saving 2 bytes of ROM.

When every byte counts, abbreviate messages. Users of 8-bit systems expect terse output.

---

## 14. Eliminate Unnecessary Defensive Code

### Remove checks that can never trigger

If control flow analysis proves a condition is impossible, the check can be removed.

**Project example** (`82285324`): `process_operators` had an explicit check for an empty operator
stack (`cpx #OP_STACK_SIZE` / `clc` / `beq @done`). The subsequent `CMP min_precedence` /
`BCC @done` already handled this case because an empty stack would load garbage that wouldn't match
the precedence requirement. The explicit check (4 bytes) was removed.

### Remove state that can be derived

**Project example** (`82285324`): `on_raise_sp` stored the stack pointer at startup for exception
handling. Since it was always `$FF`, it was replaced with `LDX #$FF`, eliminating a zero-page
variable (saving every `STA`/`LDA` of it) and the initial `TSX`/`STX`.

---

## 15. The BIT Absolute Trick ($2C)

Use the opcode byte `$2C` (`BIT absolute`) to skip over 2 bytes of code. The CPU reads the next
two bytes as an address for the BIT instruction (modifying only N, V, and Z flags) and then
continues. This effectively "hides" a 2-byte instruction:

```assembly
; Two entry points, different initial values, shared code
entry_a:
        lda     #1
        .byte   $2C             ; BIT abs: swallows next 2 bytes
entry_b:
        lda     #2              ; These 2 bytes are the "address" for BIT
        ; shared code continues here
        sta     result
```

This replaces a `JMP` (3 bytes) with the `.byte $2C` (1 byte), saving 2 bytes. However, it only
works when the "swallowed" instruction is exactly 2 bytes long, and the BIT instruction must not
cause harmful side effects (e.g., reading a hardware register at the swallowed address).

> **Caution:** This trick is clever but obscure. Comment it clearly. It can cause confusion during
> debugging and may trigger warnings in some assemblers or analysis tools. More importantly, the
> `BIT` instruction performs a real read from the address formed by the two swallowed bytes. On
> some platforms, reading certain addresses has side effects (e.g., clearing a UART receive
> register, triggering a bank switch, or acknowledging an interrupt). **Only use this trick in
> platform-specific code** where you can verify that the swallowed bytes don't form an address
> that maps to a hardware register with read side effects. Do not use it in cross-platform core
> code.

---

## 16. Use the Stack as Scratch Space

`PHA` (1 byte) is cheaper than `STA zp` (2 bytes) for temporarily saving A. Similarly, `PLA` (1
byte) is cheaper than `LDA zp` (2 bytes) for restoring it. If you only need to save a value
briefly and the stack depth is manageable, use push/pull:

```assembly
; BEFORE (4 bytes)
        sta     temp
        ...
        lda     temp

; AFTER (2 bytes)
        pha
        ...
        pla
```

This only works when the intervening code doesn't change the stack depth unexpectedly (no
unmatched JSR/RTS, PHA/PLA in between).

---

## 17. 16-Bit Byte Adjustments with BCC/INC and BCS/DEC

When adding or subtracting an 8-bit offset to/from a 16-bit pointer or integer, adjusting the high byte with conditional branching saves 2 to 4 bytes compared to using `ADC #0` or `SBC #0`.

### Adding an 8-bit offset to a 16-bit memory location

The standard approach loads the high byte, adds carry with `#0`, and stores it back (6–8 bytes depending on addressing mode):

```assembly
; CONVENTIONAL (8 bytes for high-byte propagation)
        clc
        lda     ptr
        adc     offset
        sta     ptr
        lda     ptr+1           ; 2-3 bytes
        adc     #0              ; 2 bytes
        sta     ptr+1           ; 2-3 bytes

; OPTIMIZED (4 bytes, saves 2-4 bytes)
        clc
        lda     ptr
        adc     offset
        sta     ptr
        bcc     @no_carry       ; 2 bytes
        inc     ptr+1           ; 2-3 bytes
@no_carry:
```

### Subtracting an 8-bit offset from a 16-bit memory location

When subtracting, borrow is indicated by Carry being clear (`C=0`). Use `BCS` to skip `DEC`:

```assembly
; CONVENTIONAL (8 bytes for high-byte propagation)
        sec
        lda     ptr
        sbc     offset
        sta     ptr
        lda     ptr+1           ; 2-3 bytes
        sbc     #0              ; 2 bytes
        sta     ptr+1           ; 2-3 bytes

; OPTIMIZED (4 bytes, saves 2-4 bytes)
        sec
        lda     ptr
        sbc     offset
        sta     ptr
        bcs     @no_borrow      ; 2 bytes
        dec     ptr+1           ; 2-3 bytes
@no_borrow:
```

### Adjusting 16-bit values in AX registers

When the 16-bit value is held in the `AX` register pair (low byte in A, high byte in X):

```assembly
; Adding 8-bit offset in A to AX:
        clc
        adc     offset
        bcc     @no_carry       ; 2 bytes
        inx                     ; 1 byte (vs. pha / txa / adc #0 / tax / pla = 5 bytes)
@no_carry:

; Subtracting 8-bit offset from AX:
        sec
        sbc     offset
        bcs     @no_borrow      ; 2 bytes
        dex                     ; 1 byte (vs. pha / txa / sbc #0 / tax / pla = 5 bytes)
@no_borrow:
```

---

## 18. Absorb Call-Site Instructions into Functions

Examine call sites of frequently-called subroutines to see if surrounding setup or cleanup code can
be merged into the callee.

### Move universal setup or cleanup into the function

If all callers of a subroutine perform the same instruction immediately before calling (such as
loading a fixed parameter or clearing a flag) or immediately after returning, move that instruction
into the function body to save bytes across all call sites.

### Create secondary entry points for common pre-call instructions

If only a subset of callers perform a setup instruction before calling the function, add a secondary
entry point that executes that instruction and then falls through into the main routine.

**Project example** (`3ec95e94`): Created `iny_rebase_pvm_program_ptr` which increments Y before
falling through into `rebase_pvm_program_ptr`. Multiple callers that previously did `INY` /
`JSR rebase_pvm_program_ptr` (4 bytes) now do `JSR iny_rebase_pvm_program_ptr` (3 bytes), saving 1
byte at each call site.

```assembly
; BEFORE (Call sites: 4 bytes each)
        iny
        jsr     rebase_pvm_program_ptr

; AFTER (Call sites: 3 bytes each; saves 1 byte per site)
iny_rebase_pvm_program_ptr:
        iny
rebase_pvm_program_ptr:
        inc     pvm_program_ptr
        ...
```

---

## Summary Checklist

When reviewing code for space savings, check each of these in order:

1. **CLC/SEC after branches:** Is the carry state already known?
2. **Register loads:** Is the value already in the register?
3. **JMP vs branch:** Is a flag in a known state? Can you use a 2-byte branch?
4. **JSR+RTS:** Can the last call become a JMP? (tail call)
5. **Fall-throughs:** Can routines be rearranged to eliminate jumps?
6. **Common sequences:** Do 2+ sites share the same instruction sequence?
7. **Combined tests:** Can ORA/AND merge multiple zero checks?
8. **Arithmetic tricks:** Can carry state eliminate CLC/SEC? Can CMP replace SEC+SBC?
9. **Data format:** Can tables use offsets instead of addresses?
10. **Inline vs extract:** Is a function called once (inline it) or many times (extract it)?
11. **Duplicate paths:** Do two paths differ by only 1-2 instructions?
12. **Side effects:** Do functions leave useful values in registers?
13. **Constants/strings:** Can messages be shortened?
14. **Dead checks:** Can provably-unreachable checks be removed?
15. **BIT trick:** Can $2C skip over a 2-byte instruction?
16. **Stack scratch:** Can PHA/PLA replace STA/LDA for temporaries?
17. **16-bit adjustments:** Can BCC/INC or BCS/DEC replace ADC #0 / SBC #0 for high bytes?
18. **Call-site absorption:** Can surrounding setup/cleanup code at call sites be moved into the subroutine or into a secondary entry point?
