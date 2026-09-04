<!--
SPDX-FileCopyrightText: 2022-2026 Willis Blackburn

SPDX-License-Identifier: MIT
-->

# VC83 BASIC for 6502

![VC83 BASIC running on an Apple II](VC83_on_Apple_II_small.jpg)

A floating point BASIC interpreter for the 6502 microprocessor, targeting retrocomputers, homebrew systems,
and simulators including the Apple II, Apple 1, Atari 8-bit, ac6502, and sim6502.

## Tools

To build and test the project, you need the following tools in your `PATH`:

*   **cc65 compiler package**: Specifically `cl65` (the compiler/linker) and `sim65` (the sim6502 simulator).
*   **make**: For automating the build process.
*   **m4**: A macro processor used to generate constants and zero-page definitions.
*   **expect**: Used for running automated integration tests.
*   **python**: For running the script that generates the lexer data, and other project utilities.

In addition, the project requires a Python environment in `.venv`. To create, run:

`python -m venv .venv`

Sometimes the local Python might be called `python3` instead of `python`.

## How to Build and Test

The project uses a `Makefile` to manage the build process.

*   **Build all targets**: `make`
*   **Run unit tests**: `make test`
*   **Run integration tests**: `make expect_test`

### Constant and Zero-Page Generation
The project uses `.m4` files in `src/` to ensure consistency across assembly, C, and include files.
*   `src/constants.m4` contains constant values. It is processed by `m4` to generate `src/constants.inc` (assembly) and `src/constants.h` (C).
*   `src/zeropage.m4` contains variables stored in zero page. It is processed to generate `src/zeropage.s` (zero-page definitions and exports) and `src/zeropage.h` (C headers).

## How to Run

### sim6502 (Simulator)
The simulation version can be run directly from the command line:
```bash
sim65 build/basic_sim6502
```
Or simply:
```bash
make run
```

### Apple II
The file `build/basic_apple2` is an [AppleSingle](https://nulib.com/library/AppleSingle_AppleDouble.pdf)-format executable targeting standard 48K RAM. To run it:
1.  Create an Apple II disk image (DOS 3.3). You can use a tool like [AppleCommander](https://applecommander.github.io/):
    ```bash
    java -jar ac.jar -dos140 basic.dsk
    ```
2.  Add the `build/basic_apple2` file to the disk image. Use `-as` because this is an AppleSingle file.
    ```bash
    java -jar ac.jar -as basic.dsk basic < build/basic_apple2
    ```
3.  Boot a DOS 3.3 disk in an emulator, insert the BASIC disk, and run it using `BRUN BASIC` (or `BRUN BASIC,D2` if you put `basic.dsk` in the second drive.) If you don't have an
emulator, try the one at [apple2ts.com](https://apple2ts.com).

Alternatively, the `build/basic_apple2_lc` target loads the interpreter into the Apple II Language Card RAM ($D000–$FFFF), freeing almost the entire 48K main memory for user programs and variables.

Instead of creating a new disk image, you can duplicate an existing DOS 3.3 disk image (search around for "blank DOS 3.3 boot disk" or something like that), then
you can boot and run BASIC from the same disk.

To run on real hardware, you obviously need to put `basic.dsk` on a physical disk, or on a disk emulator like
a [Floppy Emu](https://www.bigmessowires.com/floppy-emu/). If you have an actual Apple II then you presumably understand
how to do this. I've only tested on my Apple II+, so if it doesn't work on your e/c/gs, let me know.

### Apple 1

The `basic_apple1` binary targets the original Apple 1 and compatible hardware including the
[Replica-1](https://www.corshamtech.com/product/replica-1-plus/), [APL1](https://github.com/acwright/APL1),
and most Apple 1 emulators. All of these use the original Apple 1 PIA I/O at `$D010–$D013`. The binary
loads at `$4000`.

1.  Build the binary and WozMon text file:
    ```bash
    make build/basic_apple1.txt
    ```
    This creates `build/basic_apple1.txt` containing WozMon-formatted hex load text at address `$4000`.

    Alternatively, you can build `build/basic_apple1` and convert the raw binary using [bin2woz](https://github.com/acwright/bin2woz):
    ```bash
    bin2woz -a 0x4000 build/basic_apple1 > build/basic_apple1.txt
    ```
    Each line of the output contains a 4-digit hex address followed by up to 16 bytes, ready
    to be pasted into WozMon or sent via the APL1 Terminal's Send Program panel.

2.  Load the program into your Apple 1 (or emulator) using WozMon by pasting the contents
    of `build/basic_apple1.txt`.

3.  Run it:
    ```
    4000R
    ```

### Atari 8-bit

The `build/basic_atari` binary targets the Atari 8-bit family (400, 800, XL, XE) and interfaces with the Atari OS via the Central Input/Output (CIO) subsystem, featuring full channel-based I/O (`enable_io_channels`) and trigonometric functions.

The build produces an Atari DOS executable format file. In an emulator such as [Altirra](https://www.virtualdub.org/altirra.html) or [Atari800](https://atari800.github.io/), you can load and run `build/basic_atari` directly (or rename it with a `.xex` extension), or copy it to an Atari DOS disk image.

### ac6502

The `basic_ac6502` binary targets the [ac6502](https://github.com/acwright/6502) computer system and runs as a 32 KB cartridge image overlaying `$C000–$FFFF`.

1.  **Install the emulator**:
    Install Node.js (e.g., via Homebrew with `brew install node`) and install the `ac6502` emulator package globally:
    ```bash
    npm install -g ac6502
    ```

2.  **Obtain the BIOS ROM**:
    The emulator requires the system BIOS ROM (`BIOS.bin`), which can be obtained from the [6502-BIOS](https://github.com/acwright/6502-BIOS) repository on GitHub.

3.  **Run the cartridge**:
    ```bash
    ac6502 -r /path/to/BIOS.bin -c build/basic_ac6502
    ```

## Memory Map

The interpreter manages memory using several zero-page pointers:

*   `program_ptr`: Points to the start of the BASIC program.
    *   **Program structure**: Lines are stored sequentially. Each line record starts with a 1-byte size, followed by a 2-byte line number. Statements within the line begin with an offset to the next statement and end with `0`. The program ends with a "null line" (size 0).
*   `variable_name_table_ptr`: Points to the start of the Variable Name Table (VNT), which immediately follows the program.
    *   **VNT structure**: Each record starts with a size byte (MSB set if 2 bytes). The variable name follows, with the MSB set on the last character. String variables end with `$`. The variable value is stored after the name. A zero-size record terminates the table.
*   `array_name_table_ptr`: Points to the Array Name Table (ANT) following the VNT.
    *   **ANT structure**: Similar to VNT, but after the name, it contains a 1-byte arity (dimensions) followed by words defining the element size at each level for offset calculation.
*   `free_ptr`: Points to the first byte of free memory after the ANT.
*   `string_ptr`: Points to the bottom of the string space. This space grows downwards from `himem_ptr` and is compacted upwards during garbage collection.
*   `himem_ptr`: The highest address used by the interpreter and the ceiling for the string space.

## General Structure of the Interpreter

### Lexer & Parser Virtual Machine
The parser converts user input into a tokenized program in two stages:
1.  **DFA Lexer**: A dedicated lexer (`lexer.s`) processes raw input using DFA state tables generated from regexes by `generate_lexer_data.py`. It handles case folding and converts keywords into single-byte tokens.
2.  **Parser Virtual Machine (PVM)**: An **LL(1) predictive recursive-descent parser** (`parser.s`) that validates statement and expression grammar deterministically with single-token lookahead and without backtracking.
*   **Objective**: Detect syntax errors up-front and replace keywords with 1-byte tokens for compact storage and efficient execution.
*   **Type checking**: Notably, the parser does *not* perform type checking; this is handled at runtime.
*   **LIST command**: Handles the reverse process, expanding tokens back into human-readable code.

### Execution and Flow Control
The interpreter uses two stacks for expression evaluation and flow control, paired with a lazy evaluation strategy:
1.  **Value stack (`stack`)**: A page-aligned memory buffer managed by `stack_pos` (growing downward) that stores 6-byte `Value` structures (a 1-byte type tag `TYPE_NUMBER` or `TYPE_STRING`, and a 5-byte data payload). It also stores control frames for `GOSUB` and `FOR` loops (`POP` removes one control frame).
2.  **Operator stack (`op_stack`)**: A byte array managed by `op_stack_pos` (growing downward). Each 1-byte entry packs both operator precedence (high nibble) and dispatch vector ID (low nibble), allowing single-instruction precedence comparisons and direct table dispatch.

**Lazy Evaluation**: Primary expressions leave results directly in zero-page working registers (`FP0` for numbers, `S0` for string pointers, tracked by `expr_type`) without pushing to the value stack. Intermediate results are only pushed to the stack when necessary—such as preserving a left operand across binary operators, passing arguments in parameter lists, or before allocating new strings on the heap. Simple assignments and single-term expressions execute entirely in registers without touching the stack.

## Floating Point Support

VC83 BASIC uses a custom 5-byte (40-bit) floating point format documented in `src/fp.s`:
*   **Format**: `sttttttt tttttttt tttttttt tttttttt eeeeeeee`
    *   `s`: Sign bit (bit 31, 0 for positive, 1 for negative)
    *   `t`: 31-bit fractional significand with implied `1.` (stored little-endian across bytes 0–3)
    *   `e`: 8-bit biased exponent, excess-128 (`BIAS = 128`, stored in byte 4). An exponent of 0 represents zero (`0.0`). For any non-zero exponent $e \ge 1$, the actual exponent is $e - 128$ ($128 = 2^0$).
*   **Precision**: The implied 1 bit to the left of the binary point (`1.[fraction]`, conceptually similar to IEEE-754) provides 32 bits of precision (9 decimal digits).
*   **Registers**: Stored in zero page:
    *   `FP0`: Accumulator register.
    *   `FP1`: Operand register.
    *   `FPX`: 32-bit extension register extending `FP0` to 64 bits during multiplication and addition to prevent precision loss before normalization. Zero-page string pointers `S0` and `S1` overlay the same address space as `FPX`.
*   **Operations**:
    *   **Unary functions** (e.g., `SQR`, `LOG`, `fneg`, `floor`, `round`) operate directly on `FP0`.
    *   **Binary functions** (e.g., `fadd`, `fsub`, `fmul`, `fdiv`, `fcmp`) operate on `FP0` and `FP1`. Wrapper routines also accept the address of a memory operand in `AY` and load it into `FP1`.
    *   **Transcendental functions**: Trigonometric (`SIN`, `COS`, `TAN`, `ATN`), logarithmic (`LOG`), exponential (`EXP`), and power (`^`) functions are computed using Chebyshev polynomials and Taylor series via Horner's method (`fpoly` and `fpoly_odd`). Note: Trigonometric functions are omitted from the standalone 8K `apple2` target to fit in 8K, but are included in extended targets (`apple2_lc`, `atari`, `ac6502`).

The floating point system does not support subnormal values, NaN, or infinity.

## Strings

Strings in VC83 BASIC are stored in dynamic string space at the top of RAM:
*   **Layout**: `[Length Byte] [String Data...] [Relocation Offset Low] [Relocation Offset High]`
*   **Overhead**: Each string carries 3 bytes of overhead (`STRING_EXTRA = 3`): one length byte and two relocation bytes.
*   **Allocation**: Strings grow downward from `himem_ptr` toward `free_ptr`. `string_ptr` always points to the start of the most recently allocated string.
*   **Garbage collection**: When `string_ptr` reaches `free_ptr`, the interpreter triggers a linear-time ($O(n)$) **Mark-Sweep-Compact** garbage collector that runs in six phases:
    1.  Clear marks on all strings in the heap by setting the relocation high byte to `$FF` (unmarked).
    2.  Scan variables, arrays, and the value stack to mark referenced strings (setting relocation high byte to `$00`).
    3.  Calculate relocation offsets for each marked string.
    4.  Update all string pointers in variables, arrays, and the stack.
    5.  Compact marked string data down to the bottom of free space.
    6.  Shift the compacted block of live strings back up to the top of memory (`himem_ptr`).

## Testing

### C Unit Tests
Located in the `tests/` directory (e.g., `fp_test.c`). These tests are written in C but interface with the 6502 assembly code through `c_wrappers.s`, which provides a C-callable interface to assembly functions. They are run using `sim65`.

### Expect Tests
Located in `expect_tests/`. These are integration tests that use the `expect` tool to feed BASIC commands into `sim65 build/basic_sim6502` and verify the output. This ensures the interpreter behaves correctly from a user's perspective.

## VC83 BASIC vs. Microsoft BASIC

VC83 BASIC differs from Microsoft 6502 BASIC in several key areas:

*   **Parser & Syntax Validation**: Microsoft BASIC performs simple keyword token replacement on entry without syntax checking, deferring errors until runtime. VC83 BASIC uses a dedicated DFA lexer and LL(1) Parser Virtual Machine (PVM) to perform full syntax validation on entry, catching syntax errors immediately.
*   **Variable names**: Microsoft BASIC only considers the first two characters of a variable name significant (causing collisions between names like `VAR1` and `VAR2`). VC83 BASIC allows variable names of any length.
*   **String GC**: Microsoft BASIC famously pauses due to an $O(n^2)$ string collection algorithm that repeatedly scans the variable table. VC83 BASIC uses a linear $O(n)$ mark-sweep-compact collector.

However, VC83 BASIC is currently slower than Microsoft BASIC. This is an active area for development.

## What's missing?

The core interpreter is designed to fit into an 8K footprint (under 8,192 bytes, as demonstrated by the proof-of-concept `apple2` target, which omits trigonometric functions to fit). Keeping the core down to 8K leaves ample headroom for platforms to extend the language—adding full trig, channel-based I/O, graphics, and sound—within 10K, 12K, or 16K ROM or Language Card configurations (as seen in `apple2_lc`, `atari`, and `ac6502`).

VC83 BASIC does not support `DEF FN` or `ON ERROR`. Let me know if these are important.

## Extending BASIC to a New Platform

To add support for a new hardware platform:
1.  **Linker config**: Create an `ld65` configuration file in `targets/{platform}/{platform}.cfg`.
2.  **Initialization**: Implement platform-specific startup and mandatory I/O routines (`getch`, `putch`, `inkey`, `readline`, `newline`, `tab`, `save`, `load`) in `targets/{platform}/`. On failure, I/O routines should invoke `raise ERR_IO_ERROR` (non-blocking `inkey` returns carry set `C=1` when no key is waiting).
3.  **Master assembly file**: Create a `targets/{platform}/basic_{platform}.s` file that `.include`s `basic.s` (from `src/`), `main.s`, `random.s`, and your platform-specific assembly files.
4.  **Makefile**: Add the new target to the `TARGETS` list in the `Makefile` and define the build and linking rules.
5.  **Extensions (optional)**: Implement platform-specific statements and functions in `targets/{platform}/{platform}.inc` and `{platform}_extension.s`:
    *   **Keywords**: `extension_statement_keywords`, `extension_function_keywords`, `extension_custom_keywords`
    *   **PVM grammar rules**: `extension_pvm_statements`, `extension_pvm_functions`, `extension_pvm_code`
    *   **Dispatch vectors**: `extension_statement_vectors_l/h`, `extension_function_vectors_l/h`
    *   **Dispatch flags**: `extension_statement_flags`, `extension_function_flags` using `PROLOG_*` (`PROLOG_NONE`, `PROLOG_POP_FP`, `PROLOG_POP_INT`, `PROLOG_POP_STRING`) and `EPILOG_*` (`EPILOG_NONE`, `EPILOG_PUSH_FP`, `EPILOG_PUSH_INT`, `EPILOG_PUSH_STRING`) to automate stack argument evaluation and return values without boilerplate.
    *   **Channel-based I/O (`enable_io_channels`)**: For platforms supporting numbered I/O channels (Atari-style `#0`–`#7`), define `enable_io_channels` and implement driver routines `open`, `close`, `close_all`, and `xio`.
    *   See `targets/ac6502/ac6502.inc` / `ac6502_extension.s` or `targets/apple2/apple2_lc.inc` / `apple2_extension_lc.s` for examples.


## License

VC83 BASIC is available to you under the terms of the [MIT License](LICENSES/MIT.txt). You're welcome to use it with or without changes in your own projects, provided you adhere to the license terms. 

The VC83 name itself and logo are restricted. [You can share the official version](LICENSES/LicenseRef-Official-Branding.txt), but forks must be rebranded.

## Contributing

Contributions are welcome! Please keep the following in mind:

*   **Licensing**: By contributing code to this project, you agree to license your contribution under the [MIT License](LICENSES/MIT.txt).
*   **Pull requests**: Pull requests are welcome, but I can't guarantee that I'll merge them. To improve the chance of your contribution being accepted, please reach out or open an issue to discuss your proposed changes before starting work.
