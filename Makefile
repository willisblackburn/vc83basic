# SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
#
# SPDX-License-Identifier: MIT

TARGETS = sim6502 apple2
TEST_TARGET = sim6502

TESTS = $(notdir $(basename $(wildcard tests/*_test.c)))

ASMFLAGS = --create-dep $(@:.o=.d)
CFLAGS = --create-dep $(@:.o=.d)
LDFLAGS = -m $@.map

all: $(addprefix basic_,$(TARGETS))

# Goal: basic_sim6502
basic_sim6502: basic_sim6502.s basic.inc
	cl65 -t sim6502 -C sim6502/sim6502.cfg $(LDFLAGS) -o $@ $<

# Goal: basic_apple2
basic_apple2: basic_apple2.s basic.inc
	cl65 -t apple2 -C apple2/apple2.cfg $(LDFLAGS) -o $@ $<

# Tests
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

# Object files for tests
basic_tests.o: basic_tests.s basic.inc
	cl65 -t $(TEST_TARGET) -C $(TEST_TARGET)/$(TEST_TARGET).cfg -c $(ASMFLAGS) -o $@ $<

tests/%.o: tests/%.c
	cl65 -t $(TEST_TARGET) -C $(TEST_TARGET)/$(TEST_TARGET).cfg -c $(CFLAGS) -o $@ $<

.PHONY: all test clean

clean::
	rm -f $(addprefix basic_,$(TARGETS)) basic_tests.o *.o *.d *.map tests/*.o tests/*.d tests/*.map tests/*.dbg

-include *.d tests/*.d
