# VC83 BASIC

## About the project

VC83 BASIC is a BASIC interpreter written in 6502 assembly language and targeting classic 8-bit
microcomputers such as the Apple II as well as newly-designed retrocomputers.

## Coding

When working on this project,
keep in mind the very limited space available: the core interpreter needs to fit into just 8K, with
platform-specific extensions the total size can go up to 10K, 12K, or 16K, depending on the platform.
The specific version that must fit into 8K is the apple2 (not apple2_lc) binary. The code size limitation
means that we may sometimes have to select algorithms that are most space-efficient, even if they are
slower.

## Testing

Please run tests to verify your work, and add new tests as necessary. There are two types of tests. Unit
tests are written in C. To run the unit tests, use `make test`. There are also functional tests that use
the `expect` utility to send commands to the interpeter, as well as enter and run BASIC programs, and verify
the output. Run these tests using `make expect_test`.
Do not try to run the interpreter from the shell and interact with it; this does not work well. Use `expect` 
either by updating or creating functional test, or run yourself from the shell.
