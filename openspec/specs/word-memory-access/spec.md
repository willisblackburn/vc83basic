# word-memory-access Specification

## Purpose

Provides 16-bit little-endian word memory read and write keywords in core VC83 BASIC (`POKEW`, `PEEKW`) and the VC83 serial target extension (`POKEW24`, `PEEKW24`).

## Requirements

### Requirement: 16-bit CPU memory word write via POKEW
Core BASIC SHALL provide the `POKEW addr, value` statement to write a 16-bit integer in little-endian byte order to `addr` (low byte) and `addr + 1` (high byte) in the 16-bit CPU address space.

#### Scenario: Write a 16-bit word to memory
- **WHEN** a program executes `POKEW ADDR, 18761` (`$4949`)
- **THEN** memory at `ADDR` contains `$49` and memory at `ADDR + 1` contains `$49`

#### Scenario: Missing or extra arguments to POKEW
- **WHEN** a program executes `POKEW ADDR` or `POKEW ADDR, 1, 2`
- **THEN** BASIC raises a syntax error (`ERR: SYNTAX`)

#### Scenario: LIST output preserves POKEW keyword
- **WHEN** a program line containing `POKEW` is tokenized and listed with `LIST`
- **THEN** the listed output displays `POKEW`

### Requirement: 16-bit CPU memory word read via PEEKW
Core BASIC SHALL provide the `PEEKW(addr)` function to read a 16-bit unsigned integer in little-endian byte order from `addr` (low byte) and `addr + 1` (high byte) in the 16-bit CPU address space.

#### Scenario: Read a 16-bit word from memory
- **WHEN** memory at `ADDR` contains `$48` (`'H'`) and `ADDR + 1` contains `$45` (`'E'`) and a program evaluates `PEEKW(ADDR)`
- **THEN** the function returns `17736` (`$4548`)

#### Scenario: LIST output preserves PEEKW keyword
- **WHEN** a program line containing `PEEKW` is tokenized and listed with `LIST`
- **THEN** the listed output displays `PEEKW`

### Requirement: 24-bit Wishbone bus word write via POKEW24
The `vc83_serial` target extension SHALL provide the `POKEW24 addr, value` statement to write a 16-bit integer in little-endian byte order to `addr` (low byte) and `addr + 1` (high byte) in the 24-bit VC83 Wishbone address space.

#### Scenario: Write a 16-bit word to a 24-bit address
- **WHEN** a program executes `POKEW24 addr, value` on the `vc83_serial` target
- **THEN** the low byte of `value` is written to `addr` and the high byte is written to `addr + 1` via the bus accelerator

#### Scenario: Missing or extra arguments to POKEW24
- **WHEN** a program executes `POKEW24 addr` or `POKEW24 addr, 1, 2`
- **THEN** BASIC raises a syntax error (`ERR: SYNTAX`)

### Requirement: 24-bit Wishbone bus word read via PEEKW24
The `vc83_serial` target extension SHALL provide the `PEEKW24(addr)` function to read a 16-bit unsigned integer in little-endian byte order from `addr` (low byte) and `addr + 1` (high byte) in the 24-bit VC83 Wishbone address space.

#### Scenario: Read a 16-bit word from a 24-bit address
- **WHEN** a program evaluates `PEEKW24(addr)` on the `vc83_serial` target
- **THEN** the function reads the low byte at `addr` and high byte at `addr + 1` via the bus accelerator and returns the 16-bit integer value

### Requirement: Legacy DPOKE/DPEEK/DPOKE24/DPEEK24 keywords are removed
BASIC SHALL NOT recognize `DPOKE`, `DPEEK`, `DPOKE24`, or `DPEEK24` as keywords.

#### Scenario: Legacy statement keyword is rejected
- **WHEN** a user enters `DPOKE 1000, 1` or `DPOKE24 1000, 1`
- **THEN** BASIC does not tokenize it as a word-poke statement and raises a syntax error (`ERR: SYNTAX`)

#### Scenario: Legacy function keyword is not tokenized as a built-in function
- **WHEN** a user enters `PRINT DPEEK(1000)` or `PRINT DPEEK24(1000)`
- **THEN** BASIC does not recognize `DPEEK` or `DPEEK24` as a built-in function
