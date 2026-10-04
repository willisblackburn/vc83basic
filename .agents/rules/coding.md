---
trigger: always_on
---

# Coding

## Authorized Changes

Code changes must be authorized.

I will authorize you to make code changes by using imperative verbs like "implement" or "refactor" or "fix," or by using phrases like "make this do that" or "add this new feature" or "improve the algorithm." If I'm only asking a question, like "why is this happening?" or "why did you do this?" then just answer my question and let me decide what to do. If you're not sure if I want you to make changes or not, ask me.

Before making any change, ask yourself: "Did the user authorize me to make this change? [Yes/No]." If your answer is No, explain what you want to change, then wait for authorization before proceeding.

When making changes, focus on the minimum set of changes necessary to meet the objective. Don't make other unrelated changes or refactoring. If I ask you to change a module, or a function, only change that module or function. If I want you to change other things, I will say something like "update other modules to match." Let me know if you notice anything that you think should be changed and let me decide whether to do it or not.

## Keep Unrecognized Changes

If you see that I've made changes to the code, keep them. If you think my changes are wrong, ask me before removing them.

## Wait/Stop

If I say "wait," or "stop," immediately stop everything you are doing and await instructions.

## Optimize for Space

When working on this project, keep in mind the very limited space available: the core interpreter needs to fit into just 8K, with platform-specific extensions the total size can go up to 10K, 12K, or 16K, depending on the platform. The specific version that must fit into 8K is the apple2 (not apple2_lc) binary. The code size limitation means that we may sometimes have to select algorithms that are most space-efficient, even if they are slower. The `make` process will report the code size of each binary.

## Testing

Please run tests to verify your work, and add new tests as necessary.

There are two types of tests. Unit tests are written in C. To run the unit tests, use `make test`. There are also functional tests that use the `expect` utility to send commands to the interpeter, as well as enter and run BASIC programs, and verify the output. Run these tests using `make expect_test`.

Use `expect` to interact with the compiled `basic_sim6502` interpreter, either by updating or creating functional test, or run yourself from the shell. Do not try to run the interpreter from the shell and interact with it; this does not work well. 

## Coding Style

The coding style is consistent throughout the code base. Follow this style.

Comment lines starting a column 41. About half of lines should have comments. Branches usually have comments describing what the code is testing. Non-obvious arithmetic and logical expressions have comments. A common use of comments is to describe likely/possible values for variables and how the code is using the flags.

Retain all existing comments and line spacing unless you are actually changing the code in a way that makes the existing comments and line spacing no longer valid or appropriate.

Add blank lines after JMP and unconditional branches, if followed by a cheap label (beginning with `@`). It's okay to add a blank line ahead of a cheap label to break up long functions. Add blank lines around comment blocks. But otherwise keep the code compact.

Spaces around operators in expressions follow a semantic convention. Simple address and offset adjustments have **no spaces**: `var_ptr+1`, `Line::num+1`, `stack+Control::next_line_ptr,x`, `.word exec_print-1`, `#'A'-1`. Value computations have **spaces**: `#.sizeof(Line) + 2`, `1 | PROLOG_POP_FP`, `* - ready_message`, `fp_scratch + .sizeof(Float) * 2`, `.if fp_format = 5`. The distinction is whether the expression represents a location in memory (tight) or computes a value (spaced).

Prefer to use full words in variable names and not abbreviate. Use `count` not `cnt`. Use `size` not `sz`. However, *do* use `dst` and `src` for destination and source pointers, and use `ptr` instead of `pointer`.

## Minimizing Permission Checks and Command Overhead

Repeated command permission checks slow down work significantly. Minimize interactive command prompts by adopting these strategies:

1. **Static Analysis First**: Perform thorough static code, register, stack-frame, and ABI analysis rather than running speculative trial-and-error shell commands or intermediate probe scripts.
2. **Batch Verification**: Only run test commands (such as `make test && make expect_test`) once an implementation, refactor, or fix is completely in place, rather than executing partial runs after every micro-edit.
3. **Use Debug Instrumentation in Assembly**: Insert `debug $xx` statements (which trigger the target's BRK handler to dump all 6502 registers and zero-page state) to diagnose issues directly during standard test runs.
4. **Makefile Test Targets**: When focused testing is needed during debugging, add a target to the `Makefile` (such as `dummy: build/basic_sim6502` to run a specific test) and run `make dummy` instead of constructing complex ad-hoc shell one-liners.
5. **Don't `rm` Before `make`**: You should never have to `rm` a target before building it. The `Makefile` should enable `make` to correctly build all targets whenever the dependencies change. If `make` isn't working, either fix the `Makefile` or run `make clean`. 
6. **Upstream Git Operations**: Permission checks are still appropriate and required for any operations that affect the upstream Git repository (such as pushing commits, branch manipulation, or modifying remote tracking).

## Even Keyword Counts for Attribute Nybbles

Dispatch flags pack two 4-bit attribute nybbles into each byte in `dispatch_flags`. Core and platforms are separately responsible for defining an even number of keywords so the attribute nybbles align properly without bleeding across boundaries:

- **Core Statements & Functions**: The core keyword tables and vector lists must contain an even count of statements and an even count of functions (in both trig-enabled and trig-disabled configurations), padding with dummy entries if necessary.
- **Platform Extension Statements & Functions**: Platform extensions (`extension_statement_*` and `extension_function_*`) must similarly define an even number of keywords and vectors independently, so their attribute nybble definitions start on a clean byte boundary.
- **Extensions Extend, Never Replace**: Having an `.else` branch for an extension check (e.g. `.if .definedmacro(extension_...)` with an `.else` supplying core padding or alternate bytes) is a code smell that should be investigated. Extensions should *extend* the core rather than *replace* or complete trailing core data.
