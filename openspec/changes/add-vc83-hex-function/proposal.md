# Proposal

## Why

VC83 BASIC supports hexadecimal numeric literals (`$xx`) and low-level hardware inspection (`PEEK`, `PEEK24`, `PORT`, `I2C$`, `SPI$`), but has no built-in way to format integers as hexadecimal strings. Adding `HEX$(n [, width])` to the VC83 target lets programs and interactive sessions display 16-bit integer values in uppercase hexadecimal (with optional zero-padding) without writing manual conversion routines in BASIC, while keeping the 8K `apple2` core target within its 8,192-byte budget.

## What Changes

- Add the `HEX$(n [, width])` extension function to the `vc83_serial` target:
  - Accepts a 16-bit integer argument `n` (truncated toward zero via `truncate_fp_to_int`) and returns its minimal uppercase hexadecimal representation (e.g., `HEX$(0)` returns `"0"`, `HEX$(10)` returns `"A"`, `HEX$(1034)` returns `"40A"`, `HEX$(65535)` returns `"FFFF"`).
  - Accepts an optional second numeric argument `width` (`0`–`255`); when provided, pads the result with leading `'0'` characters to at least `width` characters without truncating longer values (e.g., `HEX$(10, 2)` returns `"0A"`, `HEX$(1034, 4)` returns `"040A"`).
  - Registers `TOK_HEX_S` (`$A4`) along with its keyword entry, `pvm_hex_fun` (1-to-2-arg) parse rule, dispatch vectors, and `PROLOG_NONE | EPILOG_PUSH_STRING` flags in `targets/vc83_serial/vc83_serial.inc` (with a trailing padding entry at `$A5` to preserve an even extension function count).
  - Implements `fun_hex_s` in `targets/vc83_serial/vc83_serial_extension.s`.
- No changes to BASIC core (`src/`) or other platform targets (`apple2`, `sim6502`, `atari`, `apple1`, `ac6502`).

## Capabilities

### New Capabilities
- `vc83-string-functions`: VC83 target string-formatting extension functions, starting with `HEX$(n [, width])` for uppercase hexadecimal 16-bit integer formatting with optional zero-padding.

### Modified Capabilities

## Impact

- Affected files:
  - `targets/vc83_serial/vc83_serial.inc` (token constant, keyword table, `pvm_hex_fun` rule, dispatch vectors, dispatch flags)
  - `targets/vc83_serial/vc83_serial_extension.s` (`fun_hex_s` handler)
- Token compatibility: Existing `vc83_serial` function tokens (`$9A`–`$A3`) remain unchanged; `TOK_HEX_S` is appended at `$A4`.
- Code size: Only affects `build/basic_vc83_serial`; `build/basic_apple2` remains untouched and under 8K.
