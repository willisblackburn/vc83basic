# Design

## Context

See `proposal.md` for motivation and scope.

In `vc83basic`, the lexer (`src/lexer.s`) scans an entire identifier into `line_buffer` via the DFA (`TOK_NAME`), marks the final character with `EOT`, and then looks up the complete string in the `keywords` name table using `find_name`. Because matching operates on the complete identifier rather than greedy prefixes, `POKE`, `POKEW`, `POKE24`, and `POKEW24` (and the `PEEK` equivalents) do not conflict with each other regardless of table order.

Parser dispatch uses contiguous token ranges:
- `src/parser.s`: `BRANCH_IF_RANGE TOK_POKE, 2, pvm_arg_2` covers `$50` (`TOK_POKE`) and `$51` (`TOK_DPOKE`).
- `targets/vc83_serial/vc83_serial.inc`: `BRANCH_IF_RANGE TOK_POKE24, 5, pvm_arg_2` covers `$6E` (`TOK_POKE24`) and `$6F` (`TOK_DPOKE24`) plus three subsequent statements.
- `targets/vc83_serial/vc83_serial.inc`: `BRANCH_IF_RANGE TOK_PEEK24, 5, pvm_fun_1` covers `$9C` (`TOK_PEEK24`) and `$9D` (`TOK_DPEEK24`) plus three subsequent functions.

`src/constants.inc` and `src/constants.h` are generated from `src/constants.m4` during `make`.

## Goals / Non-Goals

**Goals:**
- Rename the four keywords and their corresponding token constants and handler labels in place without shifting any token byte values.
- Keep `parser.s` and `vc83_serial.inc` range-based dispatch rules unchanged.
- Verify the rename across all build targets (`make all`) and the test suite (`make test` / `make expect_test`).

**Non-Goals:**
- Providing backwards-compatible aliases for `DPOKE`, `DPEEK`, `DPOKE24`, or `DPEEK24`.
- Changing the runtime semantics, argument handling, or byte order of any of the four operations.
- Modifying `scratch/v060/` archival files.

## Decisions

1. **Preserve existing token byte values (`$51`, `$86`, `$6F`, `$9D`)**
   - *Rationale*: Keeps all `BRANCH_IF_RANGE` tables in `src/parser.s` and `targets/vc83_serial/vc83_serial.inc`, the dispatch vector tables, and the prolog/epilog flag tables aligned with zero structural changes.
   - *Alternative*: Reassigning token IDs or reordering blocks would unnecessarily risk off-by-one dispatch bugs with no benefit.

2. **Rename internal symbols to match the new keywords**
   - *Rationale*: Renaming `TOK_DPOKE` -> `TOK_POKEW`, `TOK_DPEEK` -> `TOK_PEEKW`, `TOK_DPOKE24` -> `TOK_POKEW24`, `TOK_DPEEK24` -> `TOK_PEEKW24`, and `exec_dpoke`/`fun_dpeek`/`exec_dpoke24`/`fun_dpeek24` -> `exec_pokew`/`fun_peekw`/`exec_pokew24`/`fun_peekw24` keeps the codebase grep-clean and avoids confusing legacy names in assembly sources.
   - *Alternative*: Changing only the strings in `name_table_entry` would leave misleading `dpoke`/`dpeek` symbol names throughout the codebase.

3. **No legacy keyword aliases**
   - *Rationale*: Aliases would consume additional keyword table entries, token IDs, and ROM bytes on a 6502 target. All downstream demos in `vc83computer` are being migrated in a companion change.

## Risks / Trade-offs

- [Breaking existing BASIC programs] → Handled by the companion `convert-demos-to-pokew-peekw` change in the parent `vc83computer` repository.
- [Untested `vc83_serial` target path in `sim6502` expect tests] → `expect_tests/peek_poke.exp` runs on `sim6502` and exercises `POKEW`/`PEEKW`; `POKEW24`/`PEEKW24` are compiled into `build/basic_vc83_serial` via `make all` and verified at runtime once integrated into the VC83 simulator/ROM.
