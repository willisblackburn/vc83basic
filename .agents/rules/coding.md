---
trigger: always_on
---

# Coding

## Authorized Changes

Code changes must be authorized.

I will authorize you to make code changes by using imperative verbs like "implement" or "refactor" or "fix," or by using phrases like "make this do that" or "add this new feature" or "improve the algorithm." If I only ask a question, like "why is this happening?" or "why did you do this?" then just answer my question and let me decide what to do. If you're not sure if I want you to make changes or not, ask me.

Before making any change, ask yourself: "Did the user authorize me to make this change? [Yes/No]." If your answer is No, explain what you want to change, then wait for authorization before proceeding.

Focus on the minimum set of changes necessary to meet your objective. Don't make other unrelated changes or refactoring. If I ask you to change a module, or a function, only change that module or function. If I want you to change other things, I will say something like "update other modules to match." Let me know if you notice anything that you think should be changed and let me decide whether to do it or not.

## Keep Unrecognized Changes

If you see that I've made changes to the code, keep them. If you think my changes are wrong, ask me before removing them.

## Wait/Stop

If I say "wait," or "stop," immediately stop everything you are doing and await instructions.

## Optimize for Space

Memory is precious: the core interpreter needs to fit into just 8K; with platform-specific extensions the total size can go up to 10K, 12K, or 16K, depending on the platform. The apple2 (not apple2_lc) binary must fit into 8K. The code size limitation means that we may sometimes have to select algorithms that are most space-efficient, even if they are slower. The `make` process will report the code size of each binary.

## Testing

Run tests to verify your work, and add new tests as necessary.

There are two types of tests. Unit tests are written in C. To run the unit tests, use `make test`. There are also functional tests that use the `expect` utility to send commands to the interpeter, as well as enter and run BASIC programs, and verify the output. Run these tests using `make expect_test`.

Use `expect` to interact with the compiled `basic_sim6502` interpreter, either by updating or creating functional test, or run yourself from the shell. Do not try to run the interpreter from the shell and interact with it; this does not work well. 

Run test commands (`make test && make expect_test`) only after an implementation or fix is fully in place. For debugging, use `debug $xx` instrumentation or dedicated Makefile targets rather than ad-hoc shell one-liners. Never `rm` build targets before `make`; fix the Makefile or use `make clean` instead.

## Coding Style

The coding style is consistent throughout the code base. Follow this style.

Always use the macros defined in macros.inc (e.g., `mvax`) to make the code more compact.

Comment lines starting a column 41. About half of lines should have comments. Branches usually have comments describing what the code is testing. Non-obvious arithmetic and logical expressions have comments. A common use of comments is to describe likely/possible values for variables and how the code is using the flags.

Retain all existing comments and line spacing unless you are actually changing the code in a way that makes the existing comments and line spacing no longer valid or appropriate.

Add blank lines after JMP and unconditional branches, if followed by a cheap label (beginning with `@`). It's okay to add a blank line ahead of a cheap label to break up long functions. Add blank lines around comment blocks. But otherwise keep the code compact.

Simple address calculations and offset adjustments have **no spaces**: `var_ptr+1`, `Line::num+1`, `stack+Control::next_line_ptr,x`, `.word exec_print-1`, `#'A'-1`. Value computations have **spaces**: `#.sizeof(Line) + 2`, `1 | PROLOG_POP_FP`, `* - ready_message`, `fp_scratch + .sizeof(Float) * 2`, `.if fp_format = 5`. The distinction is whether the expression represents a location in memory (tight) or computes a value (spaced).

Prefer to use full words in variable names and not abbreviate. Use `count` not `cnt`. Use `size` not `sz`. However, *do* use `dst` and `src` for destination and source pointers, and use `ptr` instead of `pointer`.

Use "cheap labels" (labels that start with '@') for labels that you only need to reference within a single function. Do not use unnamed labels (i.e., ":+"), except in macros.

## Even Keyword Counts for Attribute Nybbles

Dispatch flags pack two 4-bit attribute nybbles into each byte in `dispatch_flags`. Core and platforms are separately responsible for defining an even number of keywords so the attribute nybbles align properly without bleeding across boundaries.

## Minimizing Permission Checks and Command Overhead

Minimize command permission checks and turnaround delay by relying on static analysis first rather than running speculative shell commands or trial-and-error scripts.
