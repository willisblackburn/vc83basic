# SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
#
# SPDX-License-Identifier: MIT

TARGETS = sim6502 apple2 atari
TEST_TARGET = sim6502

TESTS = $(notdir $(basename $(wildcard tests/*_test.c)))
EXPECT_TESTS = $(notdir $(basename $(wildcard expect_tests/*.exp)))

ASMFLAGS = --create-dep $(@:.o=.d)
CFLAGS = --create-dep $(@:.o=.d)
LDFLAGS = -m $@.map

all: $(addprefix basic_,$(TARGETS))

# Goal: basic_sim6502
basic_sim6502.o: basic_sim6502.s basic.inc constants.inc zeropage.s
	cl65 -t sim6502 -c $(ASMFLAGS) -o $@ $<

basic_sim6502: basic_sim6502.o
	cl65 -t sim6502 -C sim6502/sim6502.cfg $(LDFLAGS) -o $@ $<

# Goal: basic_apple2
basic_apple2.o: basic_apple2.s basic.inc constants.inc zeropage.s
	cl65 -t apple2 -c $(ASMFLAGS) -o $@ $<

basic_apple2: basic_apple2.o
	cl65 -t apple2 -C apple2/apple2.cfg $(LDFLAGS) -o $@ $<

# Goal: basic_atari
basic_atari.o: basic_atari.s basic.inc constants.inc zeropage.s
	cl65 -t atari -c $(ASMFLAGS) -o $@ $<

basic_atari: basic_atari.o
	cl65 -t atari -C atari/atari-asm-xex.cfg $(LDFLAGS) -o $@ $<

# Rules for building the constants files:
constants.inc: constants.m4
	m4 $< >$@

constants.h: constants.m4
	m4 -D__C__ $< >$@

# Rules for building the zero page files:
zeropage.s: zeropage.m4
	m4 -DOUTPUT=s $< >$@

zeropage.h: zeropage.m4
	m4 -DOUTPUT=h $< >$@

# Unit tests
test: $(addprefix run_,$(TESTS))

define create-test
run_$1: tests/$1
	sim65 tests/$1

tests/$1: tests/$1.o basic_tests.o
	cl65 -t $(TEST_TARGET) -C $(TEST_TARGET)/$(TEST_TARGET).cfg $(LDFLAGS) -o $$@ $$^

clean::
	rm -f tests/$1
endef

$(foreach TEST,$(TESTS),$(eval $(call create-test,$(TEST))))

basic_tests.o: basic_tests.s basic.inc constants.inc zeropage.s
	cl65 -t $(TEST_TARGET) -C $(TEST_TARGET)/$(TEST_TARGET).cfg -c $(ASMFLAGS) -o $@ $<

tests/%.o: tests/%.c constants.h zeropage.h tests/test.h
	cl65 -t $(TEST_TARGET) -C $(TEST_TARGET)/$(TEST_TARGET).cfg -c $(CFLAGS) -o $@ $<

# Integration tests
expect_test: basic_sim6502 $(addprefix run_expect_test_,$(EXPECT_TESTS))

define create-expect-test
.PHONY: run_expect_test_$1
run_expect_test_$1:
	expect expect_tests/$1.exp
endef

$(foreach TEST,$(EXPECT_TESTS),$(eval $(call create-expect-test,$(TEST))))

.PHONY: all test expect_test clean

clean::
	rm -f $(addprefix basic_,$(TARGETS)) basic_tests.o constants.inc constants.h zeropage.s zeropage.h *.o *.d *.map tests/*.o tests/*.d tests/*.map tests/*.dbg

-include $(addsuffix .d,$(addprefix basic_,$(TARGETS)))
-include $(addsuffix .d,$(addprefix tests/,$(TESTS)))
-include basic_tests.d
