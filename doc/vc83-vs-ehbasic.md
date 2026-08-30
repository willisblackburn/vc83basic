# VC83 BASIC vs. EhBASIC: Feature Comparison

A source-code-level comparison of VC83 BASIC and EhBASIC (Enhanced BASIC v2.22 by Lee Davison).

---

## Executive Summary

VC83 BASIC and EhBASIC are both compact 6502 BASIC interpreters, but they make very different design trade-offs. VC83 uses a modern, principled architecture (DFA lexer, PVM parser, mark-compact GC, full-length variable names) with **5-byte (40-bit) floats** and fits its core in ~8K. EhBASIC is a legacy project (~2002–2013, unmaintained) at ~10K with a traditional MS BASIC architecture but **4-byte (32-bit) floats** — trading precision for space — and packs in a large set of hardware-oriented features (bit manipulation, hex/binary literals, shift operators, DO/LOOP, interrupt handling).

**VC83 advantages:** Better precision (9.6 vs 7.2 digits), better architecture, smaller code, full-length variable names, linear-time GC, channelized I/O, multi-platform support with extensions, active maintenance, MIT license.

**EhBASIC advantages:** More hardware-oriented features (bit manipulation, hex/binary literals, shift operators, interrupt handling), structured loops (DO/LOOP), fast INC/DEC, built-in constants (PI), SWAP, case-sensitive variables.

---

## Floating Point: A Fundamental Design Difference

| | VC83 | EhBASIC |
|---|---|---|
| **Format** | **5-byte (40-bit)** | **4-byte (32-bit)** |
| **Mantissa** | 32 bits (~9.6 decimal digits) | 24 bits (~7.2 decimal digits) |
| **Exponent** | 8-bit excess-128 | 8-bit excess-128 |
| **Range** | ±10⁻³⁸ to ±10³⁸ | ±10⁻³⁸ to ±10³⁸ |
| **Per-variable cost** | 5 bytes | 4 bytes |
| **MS BASIC compatible** | ✅ Same format as Applesoft/CBM | ❌ Incompatible |

> [!IMPORTANT]
> This is the most fundamental difference between the two interpreters. VC83 provides ~2.4 more decimal digits of precision, which matters for scientific/engineering calculations and for programs that accumulate rounding errors. EhBASIC saves 1 byte per numeric value and per array element, which adds up in memory-constrained programs with large arrays. EhBASIC's choice also makes its math routines slightly faster (fewer bytes to process), which partly explains how it fits more features into its 10K footprint.

---

## Where VC83 Is Better

### 1. Floating-Point Precision
VC83's 40-bit floats give ~9.6 decimal digits vs EhBASIC's ~7.2. This is the same format used by Applesoft BASIC and Commodore BASIC, making VC83 results-compatible with a large body of existing BASIC programs.

### 2. Code Density
| | VC83 | EhBASIC |
|---|---|---|
| **Core size** | **~8.0K** (apple2) to **~9.5K** (sim6502) | **~10K** |

VC83 fits a substantial feature set into ~20% less ROM, despite using a larger float format.

### 3. Full-Length Variable Names

| | VC83 | EhBASIC |
|---|---|---|
| **Significance** | **Full length** (arbitrary) | **2 characters** only |
| **Keyword conflicts** | None | Uppercase names can't contain keywords (`FORMAT` → `FOR` conflict) |
| **Case sensitivity** | Case-insensitive | Case-sensitive |

VC83 preserves and matches complete variable names. In EhBASIC, `TOTAL` and `TOKEN` are the same variable, and `FORMAT` is a syntax error because it contains `FOR`. EhBASIC's case-sensitivity is interesting but is more of a side-effect of its tokenizer design than a deliberate usability feature.

### 4. Architecture Quality

| Component | VC83 | EhBASIC |
|---|---|---|
| **Lexer** | Generated DFA (Thompson NFA→DFA) | Hand-coded linear keyword search |
| **Parser** | LL(1) PVM bytecode with strict syntax validation | Ad-hoc token dispatch |
| **Syntax errors** | Caught at line entry time | Caught at runtime only |
| **Extensibility** | Macro-based platform hooks (zero core modification) | Requires source modification |

### 5. Garbage Collector

| | VC83 | EhBASIC |
|---|---|---|
| **Algorithm** | **6-phase mark-compact** (linear time) | **O(n²) scan** (MS BASIC heritage) |
| **Worst case** | Proportional to heap size | Can freeze for seconds |

### 6. I/O and File Operations

| Feature | VC83 | EhBASIC |
|---|---|---|
| `GET` (single char input) | ✅ (numeric, with channel) | ✅ (string) |
| `PUT` (single byte output) | ✅ | ❌ |
| `INKEY$` (non-blocking poll) | ✅ | ❌ |
| `SAVE` / `LOAD` | ✅ (built-in statements) | Via vectors (host must implement) |
| `OPEN` / `CLOSE` | ✅ (with `enable_io_channels`) | ❌ |
| `XIO` (extended I/O) | ✅ (Atari CIO) | ❌ |
| I/O channels (`#0`–`#7`) | ✅ | ❌ |

### 7. Other VC83 Advantages

| Feature | VC83 | EhBASIC |
|---|---|---|
| `DPEEK` / `DPOKE` (16-bit memory) | ✅ | ✅ (`DEEK`/`DOKE` — same concept) |
| `ADR(s$)` (string address) | ✅ | ✅ (`SADD(s$)` — same concept) |
| `POP` (discard GOSUB/FOR frame) | ✅ | ❌ |
| `&` operator (string concatenation) | ✅ (dedicated operator) | ❌ (uses `+` only) |
| Array dimensions | Up to **127** | Up to **3** |
| Multi-platform targets | 7 targets with platform extensions | Generic (2 vectors) |
| License | **MIT** | Non-commercial only (unclear since 2013) |

---

## Where EhBASIC Has Features VC83 Lacks

### Tier 1: Hardware-Oriented Features (High Value for 6502 Systems)

#### Hex and Binary Literal Support ⭐⭐
| | EhBASIC | VC83 |
|---|---|---|
| `$FF00` (hex literals) | ✅ | ❌ |
| `%10101010` (binary literals) | ✅ | ❌ |
| `HEX$(x)` (hex string output) | ✅ | ❌ |
| `BIN$(x)` (binary string output) | ✅ | ❌ |

> [!IMPORTANT]
> This is arguably the most impactful gap. On 6502 systems, programmers constantly work with hex addresses and binary bit patterns. Having to write `POKE 49152, 173` instead of `POKE $C000, $AD` is a significant usability burden. `HEX$` and `BIN$` are similarly valuable for debugging hardware registers.

#### Bit Manipulation ⭐⭐
| | EhBASIC | VC83 |
|---|---|---|
| `BITSET addr, bit` | ✅ | ❌ |
| `BITCLR addr, bit` | ✅ | ❌ |
| `BITTST(addr, bit)` | ✅ | ❌ |
| `<<` (shift left) | ✅ | ❌ |
| `>>` (shift right) | ✅ | ❌ |
| `EOR` (XOR operator) | ✅ | ❌ |

EhBASIC provides comprehensive bit-level operations. VC83's `AND` and `OR` operators perform 16-bit bitwise operations, but there's no XOR, no shifts, and no direct bit set/clear/test on memory.

#### Interrupt Handling ⭐
| | EhBASIC | VC83 |
|---|---|---|
| `ON IRQ GOSUB line` | ✅ | ❌ |
| `ON NMI GOSUB line` | ✅ | ❌ |
| `IRQ ON/OFF/CLEAR` | ✅ | ❌ |
| `NMI ON/OFF/CLEAR` | ✅ | ❌ |
| `RETIRQ` / `RETNMI` | ✅ | ❌ |

EhBASIC can route hardware interrupts into BASIC subroutines. This is a significant capability for interactive hardware projects, though it adds complexity and interrupt latency.

### Tier 2: Language Features (Medium Value)

#### Structured Loop: DO/LOOP
| | EhBASIC | VC83 |
|---|---|---|
| `DO ... LOOP` | ✅ | ❌ |
| `LOOP WHILE expr` | ✅ | ❌ |
| `LOOP UNTIL expr` | ✅ | ❌ |

A proper structured loop construct. In VC83, equivalent logic requires `GOTO` or `IF...GOTO` patterns.

#### Fast Increment/Decrement
| | EhBASIC | VC83 |
|---|---|---|
| `INC var` | ✅ | ❌ |
| `DEC var` | ✅ | ❌ |

Faster than `A = A + 1` because they bypass expression evaluation. Nice optimization for tight loops.

#### SWAP Command
| | EhBASIC | VC83 |
|---|---|---|
| `SWAP A, B` | ✅ | ❌ |

Exchanges values without a temporary. Works for both numeric and string variables.

#### Built-in Constants
| | EhBASIC | VC83 |
|---|---|---|
| `PI` | ✅ (3.14159274) | ❌ |
| `TWOPI` | ✅ (6.28318548) | ❌ |

Minor convenience — easily defined by the user as variables.

### Tier 3: Nice-to-Have (Low Value)

| Feature | EhBASIC | VC83 | Notes |
|---|---|---|---|
| `CALL addr` | ✅ | ❌ | `USR()` and platform `SYS` cover this |
| `WAIT addr, mask` | ✅ | ❌ | ac6502 has it as extension |
| `VARPTR(var)` | ✅ | ❌ | `ADR()` covers strings; no numeric equivalent |
| `NULL n` | ✅ | ❌ | Obsolete (slow terminals) |
| `UCASE$`/`LCASE$` | Uncertain (some refs claim yes) | ❌ | Writable in BASIC |
| NOT as bitwise | ✅ (returns -1) | Logical only (returns 1) | Different truth value conventions |

---

## Feature Parity (Both Have)

| Feature | Details |
|---|---|
| **Core math** | ABS, SGN, INT, SQR, LOG, EXP, RND |
| **Trig** | SIN, COS, TAN, ATN |
| **String functions** | LEN, STR$, VAL, ASC, CHR$, LEFT$, RIGHT$, MID$ |
| **System functions** | PEEK, POKE, USR, FRE, POS |
| **Control flow** | FOR/NEXT, IF/THEN/ELSE, GOTO, GOSUB/RETURN, ON...GOTO/GOSUB |
| **Data** | DATA, READ, RESTORE (both support RESTORE to line) |
| **Program management** | LIST, RUN, NEW, CLR, CONT, STOP, END |
| **Variables** | DEF FN, DIM, LET |
| **Multi-statement lines** | `:` separator |
| **16-bit memory** | DPEEK/DPOKE ≡ DEEK/DOKE |
| **String address** | ADR() ≡ SADD() |
| **String heap** | Downward-growing with garbage collection |
| **LOAD/SAVE** | Both support (EhBASIC via vectors) |

---

## Truth Value Convention Difference

| | VC83 | EhBASIC |
|---|---|---|
| **TRUE** | `1` (1.0) | `-1` (-1, i.e. $FFFF) |
| **FALSE** | `0` (0.0) | `0` (0) |
| **NOT** | Logical (NOT 0 → 1, NOT x → 0) | Bitwise 16-bit complement (NOT 0 → -1, NOT -1 → 0) |
| **AND/OR** | 16-bit bitwise | 16-bit bitwise |

VC83 uses `1` for true (more intuitive for PRINT), while EhBASIC uses `-1` for true (all bits set, so `AND`/`OR`/`NOT` work as both logical and bitwise operators). Both conventions are valid; MS BASIC traditionally uses `-1`.

---

## Gap Priority Assessment

If you wanted to close gaps with EhBASIC, here's a prioritized list:

| Priority | Feature | Cost Estimate | Rationale |
|:---:|---|---|---|
| 🔴 High | **Hex/binary numeric literals** (`$FF`, `%1010`) | ~80–120 bytes | Biggest usability gap for 6502 programmers |
| 🔴 High | **HEX$(x)** function | ~40–60 bytes | Essential companion to hex literals |
| 🔴 High | **XOR operator** (or EOR) | ~30–50 bytes | AND/OR exist; XOR is the missing piece |
| 🟡 Medium | **Shift operators** (`<<`, `>>`) | ~40–60 bytes | Important for bit manipulation |
| 🟡 Medium | **Bitwise NOT** (complement) | ~20–30 bytes | Currently logical-only |
| 🟡 Medium | **DO/LOOP [WHILE\|UNTIL]** | ~80–120 bytes | Structured programming convenience |
| 🟡 Medium | **INC/DEC** statements | ~40–60 bytes | Performance convenience |
| 🟡 Medium | **SWAP** | ~40–60 bytes | Cheap convenience |
| 🟢 Low | **BIN$(x)** function | ~40–50 bytes | Less commonly needed than HEX$ |
| 🟢 Low | **PI** constant | ~10–15 bytes | Trivial; stored as 5-byte float + name entry |
| 🟢 Low | **BITSET/BITCLR/BITTST** | ~60–80 bytes | Expressible via PEEK/POKE/AND/OR once XOR exists |
| 🟢 Low | **Interrupt handling** (ON IRQ/NMI) | ~150–250 bytes | Valuable but niche; large cost |
| 🟢 Low | **CALL statement** | ~15–25 bytes | USR() covers the use case |
| ⚪ Minimal | **VARPTR** | ~30–40 bytes | ADR covers strings already |
| ⚪ Minimal | **NULL** | ~15–20 bytes | Obsolete |

### Size Budget Reality

| Target | Current Size | Limit | Headroom |
|---|---|---|---|
| apple2 | 8,152 bytes | 8,192 (8K) | **40 bytes** |
| apple1 | 8,345 bytes | ~10K+ | ~1,800+ bytes |
| vc83_serial | 8,350 bytes | ~10K+ | ~1,800+ bytes |
| apple2_lc | 8,676 bytes | ~12K+ | ~3,500+ bytes |
| atari | 9,157 bytes | ~12K+ | ~3,000+ bytes |
| ac6502 | 9,451 bytes | 16K | ~6,900+ bytes |
| sim6502 | 11,453 bytes | No hard limit | Ample |

> [!WARNING]
> The apple2 target has only **40 bytes free**. Most of these features would need to be conditional or platform-extension-only for apple2. Targets with more headroom (ac6502, sim6502, atari) could accommodate most or all of these features.

---

## Summary

VC83 BASIC is the stronger interpreter in architecture, precision, naming, GC, I/O, and code density. EhBASIC compensates with a larger set of hardware-oriented features enabled by its smaller float format.

The most impactful gaps to close are **hex/binary literals** and **HEX$()** — these are daily-use features for anyone working on 6502 hardware. After that, **XOR** and **shift operators** round out the bit manipulation story. Structured loops (**DO/LOOP**) and **INC/DEC** are nice quality-of-life additions if space permits.
