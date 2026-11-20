# Design

## Context

See `proposal.md` for motivation. The VC83 BASIC target (`targets/vc83_serial/`) extends the core interpreter using the standard extension macros (`extension_function_keywords`, `extension_pvm_functions`, `extension_function_vectors_l/h`, `extension_function_flags`) and targets the 65C02 CPU.

The standalone 8K `apple2` target is currently 8,182 bytes (10 bytes under its 8,192-byte limit), so `HEX$` is added as a VC83 target extension rather than a core function.

Currently `vc83_serial` defines 10 extension functions (`TOK_LOCATE = $9A` through `TOK_BUF_S = $A3`), with Block A starting at `TOK_PORTADC = $A0`. `dispatch_flags` packs two 4-bit prolog/epilog nybbles per byte, so platforms must maintain an even count of extension functions. `expression.s` consumes `TOK_LPAREN` before calling `dispatch_function` and consumes `TOK_RPAREN` after it returns.

## Goals / Non-Goals

**Goals:**
- Implement `HEX$(n [, width])` in `targets/vc83_serial/` with minimal code size and full adherence to VC83 BASIC dispatch and coding conventions.
- Preserve existing `vc83_serial` token values (`$9A`–`$A3`) and leave core (`src/`) and all other targets untouched.
- Support standard VC83 BASIC 16-bit integer semantics (`truncate_fp_to_int`) and optional zero-padding width (`0`–`255`).

**Non-Goals:**
- 32-bit integer formatting (BASIC integers are 16-bit via `truncate_fp_to_int`).
- Truncating values when `width` is smaller than the number of significant hex digits.
- Adding `HEX$` to BASIC core or non-VC83 targets.

## Decisions

### 1. Token placement at `$A4` with `$A5` padding
- **Decision**: Define `TOK_HEX_S = $A4` after `TOK_BUF_S = $A3`, add `BRANCH_IF TOK_HEX_S, pvm_hex_fun` to `extension_pvm_functions`, and append a single dummy padding slot at `$A5` (`name_table_entry ""`, `.byte 0` in vector tables, and `(PROLOG_NONE | EPILOG_PUSH_STRING) | (0 << 4)` in `extension_function_flags`).
- **Rationale**: Keeps all existing `vc83_serial` function tokens (`$9A`–`$A3`) unchanged, preserves Block A alignment (`KEYWORD_BLOCK_A_OFFSET` at `$A0`), and satisfies the even extension function count invariant (12 entries total).
- **Alternative considered**: Inserting `HEX$` earlier in the table. Rejected to avoid renumbering existing tokens.

### 2. Optional second argument parsing via `pvm_hex_fun` and `PROLOG_NONE`
- **Decision**: Add `pvm_hex_fun` in `extension_pvm_code` (`MATCH TOK_LPAREN` / `CALL pvm_1_to_2_args` / `JUMP pvm_close_paren`, reusing the existing `pvm_1_to_2_args` subroutine) and use `PROLOG_NONE | EPILOG_PUSH_STRING`.
- **Rationale**: `PROLOG_POP_INT` only supports fixed-arity functions because `evaluate_argument_list` pushes all arguments without passing an argument count. Using `PROLOG_NONE` matches `fun_spi_s` and `fun_i2c_s`, letting `fun_hex_s` evaluate the first argument (`evaluate_expression` + `require_int_fp0`), save `AX` on the stack, check `peek_byte == TOK_COMMA`, and optionally call `eval_next_byte_arg` for `width` (defaulting `width` to `0` if omitted).
- **Alternative considered**: Modifying core `evaluate_argument_list` to track arity. Rejected to avoid touching BASIC core (`src/`).

### 3. 16-bit hex conversion and zero-padded string construction
- **Decision**:
  1. Evaluate `n` via `evaluate_expression` + `require_int_fp0` (returns 16-bit integer in `AX`, raising `ERR: TYPE` on string or `ERR: RANGE` on magnitude >= 65536).
  2. Save `AX` (`phax`), default `width = 0`; if `peek_byte == TOK_COMMA`, call `eval_next_byte_arg` to get `width` (`0`–`255`, raising `ERR: TYPE` or `ERR: RANGE` on invalid width).
  3. Extract up to 4 uppercase hex digits from the 16-bit value into a small scratch sequence (e.g., on the stack or in `buffer`), skipping leading zeros while always keeping at least 1 digit (`"0"` for value `0`), yielding `digit_count` (`1`–`4`).
  4. Compute `out_len = max(digit_count, width)`, allocate `out_len` bytes via `string_alloc`, fill the first `out_len - digit_count` positions with `'0'`, and copy the `digit_count` hex characters into the remaining positions (`(string_ptr),y` for `y = 1..out_len`).
- **Rationale**: Using `string_alloc` handles heap allocation and GC compaction cleanly, `EPILOG_PUSH_STRING` sets `S0 = string_ptr` and `expr_type = TYPE_STRING`, and computing `out_len = max(digit_count, width)` guarantees leading-zero padding without ever truncating significant digits.

## Risks / Trade-offs

- **No automated `expect_tests` coverage for `vc83_serial`**: `make expect_test` runs against `sim6502`, not `vc83_serial`. → Mitigation: Verify `HEX$` end-to-end in the `vc83_sim` behavioral simulator (using the simulator automation interface) in addition to running `make all && make test && make expect_test` in `submodules/vc83basic`.
- **Padding slot at `$A5`**: Adds 3 bytes across keyword and vector tables until another VC83 extension function is added. → Mitigation: Negligible in `vc83_serial` and immediately reclaimed by the next VC83 function.
