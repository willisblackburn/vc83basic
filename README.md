<!--
SPDX-FileCopyrightText: 2022-2026 Willis Blackburn

SPDX-License-Identifier: MIT
-->

# VC83 BASIC for 6502

![VC83 BASIC running on an Apple II](VC83_on_Apple_II_small.jpg)

A floating-point BASIC interpreter for the 6502 microprocessor, targeting the Apple II and the sim6502 simulator,
with the capability of being extended to other platforms.

## Tools

To build and test the project, you need the following tools in your `PATH`:

*   **cc65 compiler package**: Specifically `cl65` (the compiler/linker) and `sim65` (the sim6502 simulator).
*   **make**: For automating the build process.
*   **m4**: A macro processor used to generate constants and zero-page definitions.
*   **expect**: Used for running automated integration tests.

## How to Build and Test

The project uses a `Makefile` to manage the build process.

*   **Build all targets**: `make`
*   **Run unit tests**: `make test`
*   **Run integration tests**: `make expect_test`

### Constant and Zero-Page Generation
The project uses `.m4` files to ensure consistency across assembly, C, and include files.
*   `constants.m4` contains constant values. It is processed by `m4` to generate `constants.inc` (assembly) and `constants.h` (C).
*   `zeropage.m4` contains variables stored in zero page. It is processed to generate `zeropage.s` (the actual ZP definitions), `zeropage.inc` (global declarations for assembly), and `zeropage.h` (C headers).

## How to Run

### sim6502 (Simulator)
The simulation version can be run directly from the command line:
```bash
sim65 basic_sim6502
```

### Apple II
The file `basic_apple2` is an Apple II executable. To run it:
1.  Create an Apple II disk image (DOS 3.3).
2.  Add the `basic_apple2` file to the disk image. You can use tools like [AppleCommander](https://applecommander.github.io/):
    ```bash
    # Create a New DOS 3.3 disk image
    java -jar ac.jar -dos140 disk.dsk
    # Add the binary as a BIN file
    java -jar ac.jar -p disk.dsk basic bin < basic_apple2
    ```
3.  Boot the disk in an emulator or on real hardware and run it using `BRUN BASIC`.

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

### Parser Virtual Machine
The parser converts user input into a tokenized program. It is controlled by a **Parser Virtual Machine (PVM)** that uses a domain-specific language (DSL) defined in `parser.s`.
*   **Objective**: Detect syntax errors up-front and replace keywords with 1-byte tokens for efficient execution.
*   **Type checking**: Notably, the parser does *not* perform type checking; this is handled at runtime.
*   **LIST command**: Handles the reverse process, expanding tokens back into human-readable code.

### Execution and Flow Control
The interpreter uses two stacks for expression evaluation and flow control:
1.  **Primary stack**: Holds intermediate numerical and string values, as well as the
control structure used for `GOSUB` AND `FOR`. The `POP` command removes one control structure from this stack.
2.  **Operator stack**: Holds pending operators to respect precedence.

Most statements and functions are implemented by pushing values onto the primary stack and popping them to perform operations.

## Floating Point Support

VC83 BASIC uses a custom 5-byte floating-point format documented in `fp.s`:
*   **Format**: `sttttttt tttttttt tttttttt tttttttt eeeeeeee`
    *   `s`: Sign bit.
    *   `t`: 31-bit fractional significand (implied `1.` before `t`).
    *   `e`: 8-bit exponent, excess-128 (128 = $10^0$).
*   **Registers**: The system uses two main floating-point registers stored in zero page, `FP0` and `FP1`.
*   **Operations**:
    *   **Unary functions** (e.g., `SIN`, `LOG`, `NEG`) always operate on `FP0`.
    *   **Binary functions** (e.g., `FADD`, `FMUL`) operate on `FP0` and an "argument" value. The address of the argument is passed in `AX` and loaded into `FP1` before the operation.

While VC83 BASIC uses the same number of bits to represent a floating point value as Microsoft BASIC, note that
the implied digit is 1, vs. 0 in Microsoft BASIC.

The floating point system does not support subnormal values (it underflows instead), NaN, or infinity.

## Strings

Strings in VC83 BASIC are stored with the following structure:
*   **Layout**: `[Length Byte] [String Data...] [Extra Byte 1] [Extra Byte 2]`
*   **Size**: The `Length Byte` and the two extra bytes are *not* included in the reported length of the string.
*   **Allocation**: The interpreter creates new strings by moving `string_ptr` down and writing the new string at the new `string_ptr` location. Thus, `string_ptr` always points to the most recently created string.
*   **Garbage collection**: When `string_ptr` reaches `free_ptr`, the interpreter triggers a garbage collector.
    *   The collector moves all still-referenced strings to the top of the string space (towards `himem_ptr`).
    *   During collection, the two extra bytes following each string are used to store a forwarding address.

## Testing

### C Unit Tests
Located in the `tests/` directory (e.g., `fp_test.c`). These tests are written in C but interface with the 6502 assembly code through `c_wrappers.s`, which provides a C-callable interface to assembly functions. They are run using `sim65`.

### Expect Tests
Located in `expect_tests/`. These are integration tests that use the `expect` tool to feed BASIC commands into `sim65 basic_sim6502` and verify the output. This ensures the interpreter behaves correctly from a user's perspective.

## VC83 BASIC vs. Microsoft BASIC

VC83 BASIC has a few improvements over Microsoft BASIC:

*   **Variable names**: Variable names can be any length.
*   **String GC**: The string garbage collector is much more efficient.

However, VC83 BASIC is also quite a bit slower than Microsoft BASIC. This is an area for development; it doesn't seem
like it should be an unfixable problem.

## What's missing?

My goal was to fit the BASIC core into 8K. But in order to get there, I had to remove platform-specific features
such as I/O and graphics and sound statements from the core. So the BASIC interpreter that will be actually
run on real hardware will probably be 10K, 12K, or even 16K.

VC83 BASIC does not support for DEF FN or ON ERROR. Let me know if these are important.

## Extending BASIC to a New Platform

To add support for a new hardware platform:
1.  **Linker config**: Create an `ld65` configuration file (e.g., `{platform}/{platform}.cfg`).
2.  **Initialization**: Implement platform-specific startup and mandatory I/O (`readline`, `write`, `putch`) in its own directory.
3.  **Master assembly file**: Create a `basic_{platform}.s` file that `.include`s `basic.inc` and all your platform-specific assembly files.
4.  **Makefile**: Add the new target to the `TARGETS` list in the `Makefile` and define the build rules.
5.  **Extensions (optional)**: You can implement platform-specific extensions. See `apple2_extension.s` for an example.

## License

VC83 BASIC is available to you under the terms of the [MIT License](LICENSES/MIT.txt). You're welcome to use it with or without changes in your own projects, provided you adhere to the license terms. 

The VC83 name itself and logo are restricted. [You can share the official version](LICENSES/LicenseRef-Official-Branding.txt), but forks must be rebranded.

## Contributing

Contributions are welcome! Please keep the following in mind:

*   **Licensing**: By contributing code to this project, you agree to license your contribution under the [MIT License](LICENSES/MIT.txt).
*   **Pull requests**: Pull requests are welcome, but we can't guarantee that we'll merge them. To improve the chance of your contribution being accepted, please reach out or open an issue to discuss your proposed changes before starting work.
