# Proposal

## Why

The 16-bit memory access keywords `DPOKE`, `DPEEK`, `DPOKE24`, and `DPEEK24` use a `D` ("double") prefix that is inconsistent with naming by data width. Renaming them to `POKEW`, `PEEKW`, `POKEW24`, and `PEEKW24` makes the 16-bit word width explicit and keeps all four keywords anchored on the `POKE`/`PEEK` root.

## What Changes

- **BREAKING**: Rename core BASIC statement `DPOKE` to `POKEW` and function `DPEEK` to `PEEKW`. The old keyword names are removed with no aliases.
- **BREAKING**: Rename `vc83_serial` target extension statement `DPOKE24` to `POKEW24` and function `DPEEK24` to `PEEKW24`. The old keyword names are removed with no aliases.
- Rename token constants (`TOK_DPOKE` -> `TOK_POKEW`, `TOK_DPEEK` -> `TOK_PEEKW`, `TOK_DPOKE24` -> `TOK_POKEW24`, `TOK_DPEEK24` -> `TOK_PEEKW24`) and implementation labels (`exec_dpoke` -> `exec_pokew`, `fun_dpeek` -> `fun_peekw`, `exec_dpoke24` -> `exec_pokew24`, `fun_dpeek24` -> `fun_peekw24`) while keeping their existing token byte values (`$51`, `$86`, `$6F`, `$9D`).
- Update tests (`expect_tests/peek_poke.exp`) and documentation (`doc/vc83-vs-ehbasic.md`) to use the new keyword names.

## Capabilities

### New Capabilities
- `word-memory-access`: 16-bit little-endian word memory read/write keywords (`POKEW`, `PEEKW`, `POKEW24`, `PEEKW24`) in core BASIC and the `vc83_serial` target extension.

### Modified Capabilities
<!-- None -->

## Impact

- Core BASIC sources: `src/constants.m4` (and build-generated `src/constants.inc`, `src/constants.h`), `src/lexer.s`, `src/dispatch.s`, `src/poke.s`, `src/functions.s`.
- VC83 serial target sources: `targets/vc83_serial/vc83_serial.inc`, `targets/vc83_serial/vc83_serial_extension.s`.
- Tests and documentation: `expect_tests/peek_poke.exp`, `doc/vc83-vs-ehbasic.md`.
- Downstream BASIC programs (including the demos in the parent `vc83computer` repository) using `DPOKE`, `DPEEK`, `DPOKE24`, or `DPEEK24` must be updated to the new keywords.
