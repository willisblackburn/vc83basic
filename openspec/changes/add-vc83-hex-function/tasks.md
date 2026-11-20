# Tasks

## 1. Register `HEX$` in VC83 Extension Tables

- [x] 1.1 Define `TOK_HEX_S = $A4`, add `pvm_hex_fun` (`MATCH TOK_LPAREN` / `CALL pvm_1_to_2_args` / `JUMP pvm_close_paren`), and add `HEX$` plus the `$A5` even-count padding entry to `extension_function_keywords`, `extension_pvm_functions` (`BRANCH_IF TOK_HEX_S, pvm_hex_fun`), `extension_function_vectors_l`, `extension_function_vectors_h`, and `extension_function_flags` (`PROLOG_NONE | EPILOG_PUSH_STRING` + padding) in `targets/vc83_serial/vc83_serial.inc`; verify all `.assert` checks in `src/dispatch.s` pass once `fun_hex_s` is added.

## 2. Implement `fun_hex_s` Handler

- [x] 2.1 Implement `fun_hex_s` in `targets/vc83_serial/vc83_serial_extension.s` to evaluate the 16-bit integer `n` (`evaluate_expression` + `require_int_fp0`) and optional `width` (`eval_next_byte_arg`, default `0`), convert `n` to 1–4 uppercase ASCII hex digits (`"0"`–`"FFFF"`), allocate `max(digits, width)` bytes via `string_alloc`, zero-pad on the left, and copy the hex digits, following project coding style (column-41 comments, `@` cheap labels); verify `make all` succeeds for all targets and `build/basic_apple2` code size is unchanged (<= 8,192 bytes).

## 3. Verification

- [ ] 3.1 Run `make test && make expect_test` in `submodules/vc83basic` and verify all existing unit and expect tests pass with zero regressions.
- [x] 3.2 Run `vc83_sim` with the rebuilt `basic_vc83_serial` binary (via the simulator automation interface) and verify all spec scenarios: `HEX$(0)` -> `"0"`, `HEX$(10)` -> `"A"`, `HEX$(10, 2)` -> `"0A"`, `HEX$(0, 2)` -> `"00"`, `HEX$(255)` -> `"FF"`, `HEX$(1034)` -> `"40A"`, `HEX$(1034, 4)` -> `"040A"`, `HEX$(1034, 2)` -> `"40A"`, `HEX$(10, 0)` -> `"A"`, `HEX$(10, 6)` -> `"00000A"`, `HEX$(10.9)` -> `"A"`, `HEX$(65535)` -> `"FFFF"`, `HEX$(-1)` -> `"FFFF"`, `HEX$(70000)` -> `ERR: RANGE`, `HEX$(10, -1)` / `HEX$(10, 256)` -> `ERR: RANGE`, `HEX$()` / `HEX$(1,2,3)` -> `ERR: SYNTAX`, `HEX$("A")` / `HEX$(10,"2")` -> `ERR: TYPE`, and `LIST`/`RUN` of `10 PRINT "$"&HEX$(10,2)` -> `$0A`.
