# Spec Delta

## Purpose

Provides VC83-specific string-formatting extension functions in VC83 BASIC, enabling programs and interactive commands to format 16-bit integer values as hexadecimal text.

## ADDED Requirements

### Requirement: HEX$ formats a 16-bit integer as an uppercase hexadecimal string
The VC83 BASIC interpreter SHALL provide a string function `HEX$(n [, width])` that evaluates a numeric expression `n`, truncates it to a 16-bit two's-complement integer, and returns its uppercase ASCII hexadecimal representation (`"0"` through `"FFFF"`) without leading zeros unless padded by `width`.

#### Scenario: Format zero without width
- **WHEN** the user evaluates `HEX$(0)`
- **THEN** the interpreter returns `"0"`

#### Scenario: Format single-digit and multi-digit values without width
- **WHEN** the user evaluates `HEX$(10)`, `HEX$(255)`, `HEX$(1034)`, and `HEX$(65535)`
- **THEN** the interpreter returns `"A"`, `"FF"`, `"40A"`, and `"FFFF"`, respectively

#### Scenario: Truncate fractional values toward zero
- **WHEN** the user evaluates `HEX$(10.9)`
- **THEN** the interpreter truncates the argument to `10` and returns `"A"`

#### Scenario: Format negative 16-bit values in two's complement
- **WHEN** the user evaluates `HEX$(-1)`
- **THEN** the interpreter converts `-1` to 16-bit two's complement (`$FFFF`) and returns `"FFFF"`

#### Scenario: Reject out-of-range integer arguments
- **WHEN** the user evaluates `HEX$(70000)` (magnitude >= 65536)
- **THEN** the interpreter raises an out-of-range error (`ERR: RANGE`)

### Requirement: HEX$ supports optional zero-padding width
When a second numeric argument `width` (in the range `0`–`255`) is provided to `HEX$(n, width)`, the interpreter SHALL left-pad the hexadecimal string with `'0'` characters to at least `width` characters and SHALL NOT truncate values that already have more than `width` digits.

#### Scenario: Pad shorter values with leading zeros
- **WHEN** the user evaluates `HEX$(10, 2)`, `HEX$(0, 2)`, and `HEX$(1034, 4)`
- **THEN** the interpreter returns `"0A"`, `"00"`, and `"040A"`, respectively

#### Scenario: Do not truncate values wider than width
- **WHEN** the user evaluates `HEX$(1034, 2)` and `HEX$(10, 0)`
- **THEN** the interpreter returns `"40A"` and `"A"`, respectively

#### Scenario: Pad beyond 4 hex digits
- **WHEN** the user evaluates `HEX$(10, 6)`
- **THEN** the interpreter returns `"00000A"`

#### Scenario: Reject out-of-range width arguments
- **WHEN** the user evaluates `HEX$(10, -1)` or `HEX$(10, 256)`
- **THEN** the interpreter raises an out-of-range error (`ERR: RANGE`)

### Requirement: HEX$ enforces argument count and types
The VC83 BASIC interpreter SHALL require one or two numeric arguments for `HEX$` and allow its result to be used in any string expression context, including `PRINT`, assignment, concatenation, and `LIST`.

#### Scenario: Reject wrong argument count
- **WHEN** the user enters `PRINT HEX$()` or `PRINT HEX$(1,2,3)`
- **THEN** the interpreter raises a syntax error (`ERR: SYNTAX`)

#### Scenario: Reject non-numeric arguments
- **WHEN** the user evaluates `HEX$("A")` or `HEX$(10, "2")`
- **THEN** the interpreter raises a type mismatch error (`ERR: TYPE`)

#### Scenario: Use in string expressions and program listing
- **WHEN** a program contains `10 PRINT "$"&HEX$(10,2)` and is listed and run
- **THEN** `LIST` displays `10 PRINT "$"&HEX$(10,2)` and `RUN` outputs `$0A`
