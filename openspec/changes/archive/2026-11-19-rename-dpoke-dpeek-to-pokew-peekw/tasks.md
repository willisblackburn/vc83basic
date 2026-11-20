# Tasks

## 1. Core BASIC Keywords (`POKEW` / `PEEKW`)

- [x] 1.1 Rename `TOK_DPOKE` -> `TOK_POKEW` (`$51`) and `TOK_DPEEK` -> `TOK_PEEKW` (`$86`) in `src/constants.m4`, update `"DPOKE"` -> `"POKEW"` and `"DPEEK"` -> `"PEEKW"` in `src/lexer.s`, rename `exec_dpoke` -> `exec_pokew` in `src/poke.s`, rename `fun_dpeek` -> `fun_peekw` in `src/functions.s`, and update dispatch vectors and comments in `src/dispatch.s`; verify `make build/basic_sim6502` builds cleanly and regenerates `src/constants.inc` and `src/constants.h`.
- [x] 1.2 Update `expect_tests/peek_poke.exp` to test `POKEW` and `PEEKW` (including argument validation and verifying legacy `DPOKE` produces `ERR: SYNTAX`) and update `doc/vc83-vs-ehbasic.md` references from `DPEEK`/`DPOKE` to `PEEKW`/`POKEW`; verify `make test` and `make expect_test` pass.

## 2. VC83 Serial Extension Keywords (`POKEW24` / `PEEKW24`)

- [x] 2.1 Rename `TOK_DPOKE24` -> `TOK_POKEW24` (`$6F`), `TOK_DPEEK24` -> `TOK_PEEKW24` (`$9D`), `"DPOKE24"` -> `"POKEW24"`, `"DPEEK24"` -> `"PEEKW24"`, and `exec_dpoke24`/`fun_dpeek24` -> `exec_pokew24`/`fun_peekw24` (plus comments) in `targets/vc83_serial/vc83_serial.inc` and `targets/vc83_serial/vc83_serial_extension.s`; verify `make build/basic_vc83_serial` builds cleanly.

## 3. Full Build & Cleanup Verification

- [x] 3.1 Run `make all`, `make test`, and `make expect_test` across all targets and run `git grep -i -E "d(poke|peek)(24)?"` to verify zero remaining references in tracked files outside `openspec/`.
